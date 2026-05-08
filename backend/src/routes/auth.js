const express = require('express');
const { body, validationResult } = require('express-validator');
const router = express.Router();

const authService = require('../services/authService');
const authMiddleware = require('../middleware/auth');
const { authLimiter, smsLimiter } = require('../middleware/rateLimiter');
const { Track } = require('../models/Track');

// ── 工具：提取验证错误 ───────────────────────────────────────

function validate(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ code: 400, message: errors.array()[0].msg });
    return false;
  }
  return true;
}

// ── GET /api/v1/auth/tracks  获取赛道列表 ───────────────────

router.get('/tracks', async (req, res, next) => {
  try {
    const tracks = await Track.findAll({
      where: { is_active: true },
      order: [['display_order', 'ASC']],
      attributes: ['id', 'category', 'name'],
    });
    res.json({ code: 200, data: tracks });
  } catch (err) { next(err); }
});

// ── POST /api/v1/auth/sms  发送验证码 ────────────────────────

router.post('/sms', smsLimiter, [
  body('phone').matches(/^1[3-9]\d{9}$/).withMessage('手机号格式错误'),
  body('purpose').isIn(['register', 'login', 'reset_password']).withMessage('purpose 参数错误'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    await authService.sendSmsCode(req.body.phone, req.body.purpose);
    res.json({ code: 200, message: '验证码已发送' });
  } catch (err) { next(err); }
});

// ── POST /api/v1/auth/register  注册 ─────────────────────────

router.post('/register', authLimiter, [
  body('phone').matches(/^1[3-9]\d{9}$/).withMessage('手机号格式错误'),
  body('code').isLength({ min: 6, max: 6 }).withMessage('验证码格式错误'),
  body('password')
    .isLength({ min: 6, max: 18 }).withMessage('密码长度6-18位')
    .matches(/^(?=.*[a-zA-Z])(?=.*\d)/).withMessage('密码需包含字母和数字'),
  body('nickname').isLength({ min: 2, max: 10 }).withMessage('昵称长度2-10位')
    .matches(/^[\u4e00-\u9fa5a-zA-Z0-9_]+$/).withMessage('昵称只允许中文、字母、数字、下划线'),
  body('trackId').isInt({ min: 1 }).withMessage('请选择赛道'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  const { phone, code, password, nickname, trackId } = req.body;
  try {
    const valid = await authService.verifySmsCode(phone, code, 'register');
    if (!valid) return res.status(401).json({ code: 401, message: '验证码无效或已过期' });

    const result = await authService.register({ phone, password, nickname, trackId });
    res.status(201).json({ code: 201, message: '注册成功', data: result });
  } catch (err) { next(err); }
});

// ── POST /api/v1/auth/login  密码登录 ────────────────────────

router.post('/login', authLimiter, [
  body('phone').matches(/^1[3-9]\d{9}$/).withMessage('手机号格式错误'),
  body('password').notEmpty().withMessage('密码不能为空'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  const { phone, password } = req.body;
  try {
    const result = await authService.loginWithPassword({
      phone, password,
      deviceInfo: req.headers['user-agent'],
      ip: req.ip,
    });
    res.json({ code: 200, message: '登录成功', data: result });
  } catch (err) { next(err); }
});

// ── POST /api/v1/auth/login-sms  验证码登录 ──────────────────

router.post('/login-sms', authLimiter, [
  body('phone').matches(/^1[3-9]\d{9}$/).withMessage('手机号格式错误'),
  body('code').isLength({ min: 6, max: 6 }).withMessage('验证码格式错误'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  const { phone, code } = req.body;
  try {
    const result = await authService.loginWithSms({
      phone, code,
      deviceInfo: req.headers['user-agent'],
      ip: req.ip,
    });
    res.json({ code: 200, message: '登录成功', data: result });
  } catch (err) { next(err); }
});

// ── POST /api/v1/auth/reset-password  重置密码 ───────────────

router.post('/reset-password', [
  body('phone').matches(/^1[3-9]\d{9}$/).withMessage('手机号格式错误'),
  body('code').isLength({ min: 6, max: 6 }).withMessage('验证码格式错误'),
  body('newPassword')
    .isLength({ min: 6, max: 18 }).withMessage('密码长度6-18位')
    .matches(/^(?=.*[a-zA-Z])(?=.*\d)/).withMessage('密码需包含字母和数字'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    await authService.resetPassword(req.body);
    res.json({ code: 200, message: '密码重置成功' });
  } catch (err) { next(err); }
});

// ── POST /api/v1/auth/refresh  刷新 Token ────────────────────

router.post('/refresh', async (req, res, next) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ code: 400, message: 'refreshToken 不能为空' });
  }
  try {
    const tokens = await authService.refreshTokens(refreshToken);
    res.json({ code: 200, data: tokens });
  } catch (err) { next(err); }
});

// ── POST /api/v1/auth/fcm-token  更新推送 token ──────────────

router.post('/fcm-token', authMiddleware, [
  body('fcmToken').notEmpty().withMessage('fcmToken 不能为空'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    const { User } = require('../models/User');
    await User.update({ fcm_token: req.body.fcmToken }, { where: { id: req.user.id } });
    res.json({ code: 200, message: '推送 token 已更新' });
  } catch (err) { next(err); }
});

module.exports = router;
