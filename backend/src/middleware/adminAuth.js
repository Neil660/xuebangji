const authMiddleware = require('./auth');

// 在 authMiddleware 之后使用，确保 req.user 已设置
async function adminMiddleware(req, res, next) {
  try {
    const { User } = require('../models/User');
    const user = await User.findByPk(req.user.id, {
      attributes: ['id', 'is_admin'],
    });

    if (!user || !user.is_admin) {
      return res.status(403).json({ code: 403, message: '需要管理员权限' });
    }

    next();
  } catch (err) {
    next(err);
  }
}

module.exports = adminMiddleware;
