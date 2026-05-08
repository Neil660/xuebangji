const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');
const { User } = require('../models/User');
const { SmsCode, LoginLog } = require('../models/Auth');

// ── 工具函数 ────────────────────────────────────────────────

function generateTokens(userId) {
  const accessToken = jwt.sign(
    { userId },
    process.env.JWT_ACCESS_SECRET,
    { expiresIn: process.env.JWT_ACCESS_EXPIRES || '2h' }
  );
  const refreshToken = jwt.sign(
    { userId },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES || '30d' }
  );
  return { accessToken, refreshToken };
}

function generateSmsCode() {
  // 开发模式下使用固定验证码方便测试
  if (process.env.NODE_ENV !== 'production') {
    return '123456';
  }
  return String(Math.floor(100000 + Math.random() * 900000));
}

// ── 短信验证码（生产需接入阿里云短信SDK）──────────────────────

async function sendSmsCode(phone, purpose) {
  const code = generateSmsCode();
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5分钟

  // 先作废该手机号同类型的旧验证码
  await SmsCode.update(
    { is_used: true },
    { where: { phone, purpose, is_used: false } }
  );

  await SmsCode.create({ phone, code, purpose, expires_at: expiresAt });

  // TODO: 生产环境接入阿里云短信
  // await aliyunSms.sendCode(phone, code);
  console.log(`[DEV] 验证码 ${phone}: ${code}`);

  return true;
}

async function verifySmsCode(phone, code, purpose) {
  const record = await SmsCode.findOne({
    where: {
      phone,
      code,
      purpose,
      is_used: false,
      expires_at: { [Op.gt]: new Date() },
    },
    order: [['created_at', 'DESC']],
  });

  if (!record) return false;

  await record.update({ is_used: true });
  return true;
}

// ── 注册 ─────────────────────────────────────────────────────

async function register({ phone, password, nickname, trackId }) {
  // 检查手机号是否已注册
  const existPhone = await User.findOne({ where: { phone } });
  if (existPhone) throw Object.assign(new Error('手机号已注册'), { status: 409 });

  // 检查昵称是否已占用
  const existNick = await User.findOne({ where: { nickname } });
  if (existNick) throw Object.assign(new Error('昵称已被使用'), { status: 409 });

  const passwordHash = await bcrypt.hash(password, 12);

  const user = await User.create({
    phone,
    password_hash: passwordHash,
    nickname,
    track_id: trackId,
  });

  const tokens = generateTokens(user.id);
  return { user: sanitizeUser(user), ...tokens };
}

// ── 手机号+密码登录 ──────────────────────────────────────────

async function loginWithPassword({ phone, password, deviceInfo, ip }) {
  const user = await User.findOne({ where: { phone } });
  if (!user) throw Object.assign(new Error('手机号或密码错误'), { status: 401 });

  const match = await bcrypt.compare(password, user.password_hash || '');
  if (!match) throw Object.assign(new Error('手机号或密码错误'), { status: 401 });

  await LoginLog.create({ user_id: user.id, device_info: deviceInfo, ip_address: ip });

  const tokens = generateTokens(user.id);
  return { user: sanitizeUser(user), ...tokens };
}

// ── 手机号+验证码登录 ─────────────────────────────────────────

async function loginWithSms({ phone, code, deviceInfo, ip }) {
  const valid = await verifySmsCode(phone, code, 'login');
  if (!valid) throw Object.assign(new Error('验证码无效或已过期'), { status: 401 });

  const user = await User.findOne({ where: { phone } });
  if (!user) throw Object.assign(new Error('手机号未注册'), { status: 404 });

  await LoginLog.create({ user_id: user.id, device_info: deviceInfo, ip_address: ip });

  const tokens = generateTokens(user.id);
  return { user: sanitizeUser(user), ...tokens };
}

// ── 重置密码 ─────────────────────────────────────────────────

async function resetPassword({ phone, code, newPassword }) {
  const valid = await verifySmsCode(phone, code, 'reset_password');
  if (!valid) throw Object.assign(new Error('验证码无效或已过期'), { status: 401 });

  const user = await User.findOne({ where: { phone } });
  if (!user) throw Object.assign(new Error('手机号未注册'), { status: 404 });

  const passwordHash = await bcrypt.hash(newPassword, 12);
  await user.update({ password_hash: passwordHash });

  return true;
}

// ── 刷新 Token ───────────────────────────────────────────────

async function refreshTokens(refreshToken) {
  let payload;
  try {
    payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
  } catch {
    throw Object.assign(new Error('Refresh token 无效'), { status: 401 });
  }

  const user = await User.findByPk(payload.userId);
  if (!user) throw Object.assign(new Error('用户不存在'), { status: 401 });

  return generateTokens(user.id);
}

// ── 脱敏输出 ─────────────────────────────────────────────────

function sanitizeUser(user) {
  const obj = user.toJSON ? user.toJSON() : { ...user };
  delete obj.password_hash;
  delete obj.wechat_openid;
  delete obj.qq_openid;
  delete obj.fcm_token;
  return obj;
}

module.exports = {
  sendSmsCode,
  verifySmsCode,
  register,
  loginWithPassword,
  loginWithSms,
  resetPassword,
  refreshTokens,
  sanitizeUser,
};
