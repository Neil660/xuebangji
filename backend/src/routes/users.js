const express = require('express');
const { body, validationResult } = require('express-validator');
const multer = require('multer');
const path = require('path');
const router = express.Router();

const authMiddleware = require('../middleware/auth');
const { User } = require('../models/User');
const { LoginLog } = require('../models/Auth');
const { LearningRecord } = require('../models/LearningRecord');
const { fn, col, Op, literal } = require('sequelize');
const bcrypt = require('bcryptjs');

router.use(authMiddleware);

// 文件上传配置
const upload = multer({
  dest: path.join(__dirname, '../../uploads/avatars'),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_, file, cb) => {
    const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/bmp', 'image/svg+xml'];
    const ok = allowed.includes(file.mimetype);
    if (!ok) {
      cb(new Error('不支持的图片格式: ' + file.mimetype + '，仅支持 JPG/PNG/WebP/GIF/BMP'));
    } else {
      cb(null, true);
    }
  },
});

function validate(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ code: 400, message: errors.array()[0].msg });
    return false;
  }
  return true;
}

// ── GET /users/me — 获取当前用户信息 ─────────────────────────

router.get('/me', async (req, res, next) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: { exclude: ['password_hash', 'wechat_openid', 'qq_openid'] },
    });
    if (!user) return res.status(404).json({ code: 404, message: '用户不存在' });

    // 查询标签
    const [badges] = await User.sequelize.query(
      'SELECT badge_type FROM user_badges WHERE user_id = ?',
      { replacements: [req.user.id] }
    );

    // 查询累计学习天数
    const [dayCount] = await User.sequelize.query(
      `SELECT COUNT(DISTINCT DATE(started_at)) as count
       FROM learning_records
       WHERE user_id = ? AND cheat_flag = false`,
      { replacements: [req.user.id] }
    );

    res.json({
      code: 200,
      data: {
        ...user.toJSON(),
        badges: badges.map((b) => b.badge_type),
        studyDays: parseInt(dayCount[0]?.count || 0),
      },
    });
  } catch (err) { next(err); }
});

// ── PATCH /users/me — 修改个人信息 ───────────────────────────

router.patch('/me', [
  body('nickname').optional().isLength({ min: 2, max: 10 })
    .matches(/^[\u4e00-\u9fa5a-zA-Z0-9_]+$/).withMessage('昵称格式不合法'),
  body('trackId').optional().isInt({ min: 1 }),
  body('dailyGoalSec').optional().isInt({ min: 0 }),
  body('weeklyGoalSec').optional().isInt({ min: 0 }),
  body('monthlyGoalSec').optional().isInt({ min: 0 }),
  body('antiSwitchSec').optional().isInt({ min: 5, max: 300 }),
  body('showAds').optional().isBoolean(),
  body('showDetails').optional().isBoolean(),
  body('showRank').optional().isBoolean(),
  body('avatarUrl').optional().isString(),
  body('gender').optional().isIn(['male', 'female', 'secret']),
  body('birthday').optional().isDate(),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    const user = await User.findByPk(req.user.id);
    if (!user) return res.status(404).json({ code: 404, message: '用户不存在' });

    const allowed = [
      'nickname', 'trackId', 'avatarUrl', 'gender', 'birthday',
      'dailyGoalSec', 'weeklyGoalSec', 'monthlyGoalSec',
      'antiSwitchSec', 'showAds', 'showDetails', 'showRank',
    ];

    const updates = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        // camelCase → snake_case
        const snakeKey = key.replace(/([A-Z])/g, '_$1').toLowerCase();
        updates[snakeKey] = req.body[key];
      }
    }

    // 昵称唯一性检查
    if (updates.nickname) {
      const exist = await User.findOne({
        where: { nickname: updates.nickname, id: { [Op.ne]: req.user.id } },
      });
      if (exist) return res.status(409).json({ code: 409, message: '昵称已被使用' });
    }

    await user.update(updates);
    res.json({ code: 200, message: '更新成功' });
  } catch (err) { next(err); }
});

// ── POST /users/me/password — 修改密码 ───────────────────────

router.post('/me/password', [
  body('oldPassword').notEmpty().withMessage('请输入旧密码'),
  body('newPassword')
    .isLength({ min: 6, max: 18 })
    .matches(/^(?=.*[a-zA-Z])(?=.*\d)/).withMessage('新密码需包含字母和数字'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    const user = await User.findByPk(req.user.id);
    const match = await bcrypt.compare(req.body.oldPassword, user.password_hash || '');
    if (!match) return res.status(401).json({ code: 401, message: '旧密码错误' });

    const newHash = await bcrypt.hash(req.body.newPassword, 12);
    await user.update({ password_hash: newHash });
    res.json({ code: 200, message: '密码修改成功' });
  } catch (err) { next(err); }
});

// ── POST /users/me/avatar — 上传头像 ─────────────────────────

router.post('/me/avatar', (req, res, next) => {
  upload.single('avatar')(req, res, (err) => {
    if (err) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ code: 400, message: '图片大小不能超过5MB' });
      }
      if (err.message && err.message.includes('mimetype')) {
        return res.status(400).json({ code: 400, message: '仅支持 JPG/PNG/WebP 格式' });
      }
      console.error('[头像上传] Multer错误:', err.message);
      return res.status(500).json({ code: 500, message: '文件上传失败: ' + err.message });
    }
    if (!req.file) {
      return res.status(400).json({ code: 400, message: '请选择图片文件' });
    }
    const url = `/uploads/avatars/${req.file.filename}`;
    User.update({ avatar_url: url }, { where: { id: req.user.id } })
      .then(() => res.json({ code: 200, data: { avatarUrl: url } }))
      .catch((e) => { console.error('[头像上传] DB错误:', e.message); next(e); });
  });
});

// ── GET /users/me/login-logs — 查看登录记录 ──────────────────

router.get('/me/login-logs', async (req, res, next) => {
  try {
    const logs = await LoginLog.findAll({
      where: {
        user_id: req.user.id,
        logged_at: { [Op.gte]: new Date(Date.now() - 30 * 24 * 3600 * 1000) },
      },
      order: [['logged_at', 'DESC']],
      limit: 20,
    });
    res.json({ code: 200, data: logs });
  } catch (err) { next(err); }
});

// ── GET /users/me/stats — 用户数据汇总（个人中心）────────────

router.get('/me/stats', async (req, res, next) => {
  try {
    const uid = req.user.id;

    const [[total], [dayCount], dates] = await Promise.all([
      User.sequelize.query(
        `SELECT COALESCE(SUM(duration_seconds), 0) as total
         FROM learning_records WHERE user_id = ? AND cheat_flag = false`,
        { replacements: [uid] }
      ),
      User.sequelize.query(
        `SELECT COUNT(DISTINCT DATE(started_at)) as count
         FROM learning_records WHERE user_id = ? AND cheat_flag = false`,
        { replacements: [uid] }
      ),
      User.sequelize.query(
        `SELECT DISTINCT DATE(started_at) d FROM learning_records
         WHERE user_id = ? AND cheat_flag = false ORDER BY d`,
        { replacements: [uid] }
      ),
    ]);

    const totalSec  = parseInt(total[0]?.total || 0);
    const studyDays = parseInt(dayCount[0]?.count || 0);
    const avgSec    = studyDays > 0 ? Math.round(totalSec / studyDays) : 0;

    // JS计算最长连续天数
    let maxStreak = 0;
    if (dates && dates.length > 0) {
      const days = dates.map(r => new Date(r.d));
      let streak = 1;
      for (let i = 1; i < days.length; i++) {
        const diff = (days[i] - days[i-1]) / 86400000;
        if (diff <= 1) { streak++; }
        else { maxStreak = Math.max(maxStreak, streak); streak = 1; }
      }
      maxStreak = Math.max(maxStreak, streak);
    }

    res.json({
      code: 200,
      data: {
        totalSec,
        studyDays,
        avgDailySec: avgSec,
        maxStreakDays: maxStreak,
      },
    });
  } catch (err) { next(err); }
});

module.exports = router;
