const rateLimit = require('express-rate-limit');

const defaultLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分钟
  max: 300,
  message: { code: 429, message: '请求过于频繁，请稍后再试' },
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,  // 5分钟
  max: 10,
  message: { code: 429, message: '登录尝试过于频繁，请5分钟后再试' },
});

const smsLimiter = rateLimit({
  windowMs: 60 * 1000, // 1分钟
  max: 2,
  message: { code: 429, message: '短信发送过于频繁，请1分钟后再试' },
  keyGenerator: (req) => req.body?.phone || req.ip,
});

module.exports = { defaultLimiter, authLimiter, smsLimiter };
