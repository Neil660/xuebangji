const express = require('express');
const { query, validationResult } = require('express-validator');
const router = express.Router();

const authMiddleware = require('../middleware/auth');
const leaderboardService = require('../services/leaderboardService');
const { User } = require('../models/User');
const { Track } = require('../models/Track');
const { Advertisement } = require('../models/Advertisement');

router.use(authMiddleware);

function validate(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ code: 400, message: errors.array()[0].msg });
    return false;
  }
  return true;
}

// ── GET /leaderboard — 获取排行榜 ────────────────────────────

router.get('/', [
  query('trackId').optional().isInt({ min: 1 }),
  query('period').optional().isIn(['day', 'week', 'month', 'total']),
  query('limit').optional().isInt({ min: 1, max: 100 }),
], async (req, res, next) => {
  if (!validate(req, res)) return;

  // 默认使用用户所在赛道
  const trackId = parseInt(req.query.trackId) || req.user.trackId;
  const period  = req.query.period || 'day';
  const limit   = parseInt(req.query.limit) || 100;

  if (!trackId) {
    return res.status(400).json({ code: 400, message: '请先设置赛道' });
  }

  try {
    const [entries, track, myRank, ad] = await Promise.all([
      leaderboardService.getLeaderboard(trackId, period, new Date(), limit, req.user.id),
      Track.findByPk(trackId, { attributes: ['id', 'name', 'category'] }),
      leaderboardService.getUserRank(req.user.id, trackId, period),
      _getCurrentAd(period),
    ]);

    res.json({
      code: 200,
      data: {
        track,
        period,
        entries,
        myRank,
        advertisement: ad,
        refreshedAt: new Date().toISOString(),
      },
    });
  } catch (err) { next(err); }
});

// ── GET /leaderboard/my-rank — 获取个人在各榜的排名 ───────────

router.get('/my-rank', async (req, res, next) => {
  const trackId = req.user.trackId;
  if (!trackId) {
    return res.status(400).json({ code: 400, message: '请先设置赛道' });
  }

  try {
    const periods = ['day', 'week', 'month', 'total'];
    const ranks = await Promise.all(
      periods.map((p) => leaderboardService.getUserRank(req.user.id, trackId, p))
    );
    const result = {};
    periods.forEach((p, i) => { result[p] = ranks[i]; });

    res.json({ code: 200, data: result });
  } catch (err) { next(err); }
});

// ── GET /leaderboard/user/:userId — 查看用户学习明细（脱敏）──

router.get('/user/:userId', async (req, res, next) => {
  try {
    const targetUser = await User.findByPk(req.params.userId, {
      attributes: ['id', 'nickname', 'avatar_url', 'show_details', 'track_id'],
    });
    if (!targetUser) {
      return res.status(404).json({ code: 404, message: '用户不存在' });
    }

    if (!targetUser.show_details) {
      return res.json({
        code: 200,
        data: { nickname: targetUser.nickname, details: [] },
      });
    }

    // 仅返回近7天每日时长（脱敏：不返回具体时间/备注）
    const { LearningRecord } = require('../models/LearningRecord');
    const { fn, col, Op } = require('sequelize');
    const since = new Date(Date.now() - 7 * 24 * 3600 * 1000);

    const daily = await LearningRecord.findAll({
      attributes: [
        [fn('DATE', col('started_at')), 'date'],
        [fn('SUM', col('duration_seconds')), 'total'],
        'subject_name',
      ],
      where: {
        user_id: targetUser.id,
        started_at: { [Op.gte]: since },
        cheat_flag: false,
      },
      group: [fn('DATE', col('started_at')), 'subject_name'],
      order: [[fn('DATE', col('started_at')), 'DESC']],
    });

    res.json({
      code: 200,
      data: {
        userId: targetUser.id,
        nickname: targetUser.nickname,
        avatarUrl: targetUser.avatar_url,
        details: daily.map((d) => ({
          date: d.get('date'),
          subjectName: d.subject_name,
          totalSec: parseInt(d.get('total')),
        })),
      },
    });
  } catch (err) { next(err); }
});

// ── 获取当前广告（月榜/总榜才显示赞助广告）─────────────────────

async function _getCurrentAd(period) {
  if (!['month', 'total'].includes(period)) return null;

  const now = new Date();
  const monthStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  const ad = await Advertisement.findOne({
    where: { is_active: true, period_type: period },
    order: [['created_at', 'DESC']],
  });

  if (!ad) return null;

  // 月榜广告检查是否在有效月份
  if (period === 'month' && ad.months) {
    const months = JSON.parse(ad.months);
    if (!months.includes(monthStr)) return null;
  }

  return {
    advertiserName: ad.advertiser_name,
    materialImage:  ad.material_image,
    materialName:   ad.material_name,
  };
}

module.exports = router;