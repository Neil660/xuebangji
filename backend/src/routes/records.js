const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { Op, fn, col, literal } = require('sequelize');
const moment = require('moment');
const router = express.Router();

const authMiddleware = require('../middleware/auth');
const { LearningRecord } = require('../models/LearningRecord');
const { Subject } = require('../models/Subject');
const leaderboardService = require('../services/leaderboardService');
const antiCheatService   = require('../services/antiCheatService');

router.use(authMiddleware);

function validate(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ code: 400, message: errors.array()[0].msg });
    return false;
  }
  return true;
}

// ── POST /records — 提交学习记录 ─────────────────────────────

router.post('/', [
  body('startedAt').isISO8601().withMessage('startedAt 格式错误'),
  body('endedAt').isISO8601().withMessage('endedAt 格式错误'),
  body('durationSeconds')
    .isInt({ min: 1, max: 86400 })
    .withMessage('时长必须在1秒到86400秒之间'),
  body('subjectId').optional().isInt({ min: 1 }),
  body('note').optional().isLength({ max: 200 }),
], async (req, res, next) => {
  if (!validate(req, res)) return;

  const { startedAt, endedAt, durationSeconds, subjectId, note } = req.body;
  try {
    // 获取科目名称
    let subjectName = null;
    if (subjectId) {
      const subj = await Subject.findOne({
        where: { id: subjectId, user_id: req.user.id },
      });
      subjectName = subj?.name || null;
    }

    // 防作弊检测
    const cheatResult = await antiCheatService.check(req.user.id, durationSeconds);

    const record = await LearningRecord.create({
      user_id: req.user.id,
      subject_id: subjectId || null,
      subject_name: subjectName,
      started_at: new Date(startedAt),
      ended_at: new Date(endedAt),
      duration_seconds: durationSeconds,
      note: note || null,
      cheat_flag: cheatResult.isCheat,
      cheat_reason: cheatResult.reason || null,
    });

    // 更新排行榜（非作弊）
    if (!cheatResult.isCheat) {
      await leaderboardService.addDuration(
        req.user.id,
        req.user.trackId,
        durationSeconds,
        new Date(startedAt)
      );
    }

    res.status(201).json({ code: 201, data: record });
  } catch (err) { next(err); }
});

// ── GET /records — 查询学习记录列表 ──────────────────────────

router.get('/', [
  query('startDate').optional().isDate(),
  query('endDate').optional().isDate(),
  query('subjectId').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('offset').optional().isInt({ min: 0 }),
], async (req, res, next) => {
  if (!validate(req, res)) return;

  const { startDate, endDate, subjectId } = req.query;
  const limit  = parseInt(req.query.limit)  || 50;
  const offset = parseInt(req.query.offset) || 0;

  const where = { user_id: req.user.id };
  if (startDate) where.started_at = { [Op.gte]: new Date(startDate) };
  if (endDate) {
    where.started_at = {
      ...(where.started_at || {}),
      [Op.lt]: new Date(moment(endDate).add(1, 'day').format('YYYY-MM-DD')),
    };
  }
  if (subjectId) where.subject_id = parseInt(subjectId);

  try {
    const { count, rows } = await LearningRecord.findAndCountAll({
      where,
      order: [['started_at', 'DESC']],
      limit,
      offset,
    });
    res.json({ code: 200, data: { total: count, list: rows, limit, offset } });
  } catch (err) { next(err); }
});

// ── GET /records/stats — 时长统计 ────────────────────────────

router.get('/stats', async (req, res, next) => {
  try {
    const userId = req.user.id;
    const now = moment();

    const [today, week, month, total] = await Promise.all([
      _sumDuration(userId, now.format('YYYY-MM-DD'), now.clone().add(1, 'day').format('YYYY-MM-DD')),
      _sumDuration(userId, now.clone().startOf('isoWeek').format('YYYY-MM-DD')),
      _sumDuration(userId, now.clone().startOf('month').format('YYYY-MM-DD')),
      _sumDuration(userId),
    ]);

    // 科目统计（本月）
    const subjectStats = await LearningRecord.findAll({
      attributes: [
        'subject_name',
        [fn('SUM', col('duration_seconds')), 'total'],
      ],
      where: {
        user_id: userId,
        started_at: { [Op.gte]: now.clone().startOf('month').toDate() },
        cheat_flag: false,
      },
      group: ['subject_name'],
      order: [[literal('total'), 'DESC']],
    });

    res.json({
      code: 200,
      data: {
        todaySec: today,
        weekSec: week,
        monthSec: month,
        totalSec: total,
        subjectStats: subjectStats.map((s) => ({
          name: s.subject_name || '未分类',
          totalSec: parseInt(s.get('total')),
        })),
      },
    });
  } catch (err) { next(err); }
});

// ── GET /records/trend — 趋势（近7天/近30天每日时长）────────

router.get('/trend', [
  query('days').optional().isIn(['7', '30']),
], async (req, res, next) => {
  if (!validate(req, res)) return;

  const days = parseInt(req.query.days) || 7;
  const start = moment().subtract(days - 1, 'days').startOf('day').toDate();

  try {
    const rows = await LearningRecord.findAll({
      attributes: [
        [fn('DATE', col('started_at')), 'date'],
        [fn('SUM', col('duration_seconds')), 'total'],
      ],
      where: {
        user_id: req.user.id,
        started_at: { [Op.gte]: start },
        cheat_flag: false,
      },
      group: [fn('DATE', col('started_at'))],
      order: [[fn('DATE', col('started_at')), 'ASC']],
    });

    // 补全缺失日期
    const map = new Map(rows.map((r) => [r.get('date'), parseInt(r.get('total'))]));
    const trend = [];
    for (let i = days - 1; i >= 0; i--) {
      const date = moment().subtract(i, 'days').format('YYYY-MM-DD');
      trend.push({ date, totalSec: map.get(date) || 0 });
    }

    res.json({ code: 200, data: trend });
  } catch (err) { next(err); }
});

// ── DELETE /records/:id — 删除记录（可选，需确认） ──────────

router.delete('/:id', async (req, res, next) => {
  try {
    const record = await LearningRecord.findOne({
      where: { id: req.params.id, user_id: req.user.id },
    });
    if (!record) return res.status(404).json({ code: 404, message: '记录不存在' });
    await record.destroy();
    res.json({ code: 200, message: '记录已删除' });
  } catch (err) { next(err); }
});

// ── 工具函数 ─────────────────────────────────────────────────

async function _sumDuration(userId, startDate, endDate) {
  const where = { user_id: userId, cheat_flag: false };
  if (startDate) where.started_at = { [Op.gte]: new Date(startDate) };
  if (endDate) where.started_at = { ...(where.started_at || {}), [Op.lt]: new Date(endDate) };

  const result = await LearningRecord.findOne({
    attributes: [[fn('SUM', col('duration_seconds')), 'total']],
    where,
  });
  return parseInt(result?.get('total') || 0);
}

module.exports = router;
