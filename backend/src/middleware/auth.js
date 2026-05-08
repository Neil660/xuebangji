const jwt = require('jsonwebtoken');
const { User } = require('../models/User');

async function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ code: 401, message: '未提供认证令牌' });
    }

    const token = authHeader.slice(7);
    const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET);

    const user = await User.findByPk(payload.userId, {
      attributes: ['id', 'nickname', 'track_id', 'is_banned', 'ban_until'],
    });

    if (!user) {
      return res.status(401).json({ code: 401, message: '用户不存在' });
    }

    if (user.is_banned) {
      const now = new Date();
      if (!user.ban_until || user.ban_until > now) {
        return res.status(403).json({
          code: 403,
          message: `账号已被封禁`,
          banUntil: user.ban_until,
        });
      }
      // 解封
      await user.update({ is_banned: false, ban_until: null });
    }

    req.user = { id: user.id, trackId: user.track_id, nickname: user.nickname };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ code: 4011, message: '令牌已过期，请刷新' });
    }
    return res.status(401).json({ code: 401, message: '无效令牌' });
  }
}

module.exports = authMiddleware;
