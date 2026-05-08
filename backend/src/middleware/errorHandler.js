function errorHandler(err, req, res, next) {
  console.error(`[ERROR] ${err.message}`, {
    url: req.url,
    method: req.method,
    stack: err.stack?.split('\n').slice(0, 3).join('\n'),
  });

  // Sequelize 验证错误
  if (err.name === 'SequelizeValidationError') {
    return res.status(400).json({
      code: 400,
      message: err.errors.map((e) => e.message).join('; '),
    });
  }

  if (err.name === 'SequelizeUniqueConstraintError') {
    return res.status(409).json({ code: 409, message: '数据已存在，请勿重复提交' });
  }

  // SQLite 唯一约束错误
  if (err.name === 'SequelizeUniqueConstraintError' ||
      (err.message && err.message.includes('UNIQUE constraint failed'))) {
    return res.status(409).json({ code: 409, message: '数据已存在，请勿重复提交' });
  }

  const status = err.status || 500;
  res.status(status).json({
    code: status,
    message: status === 500 ? '服务器内部错误' : err.message,
  });
}

module.exports = errorHandler;
