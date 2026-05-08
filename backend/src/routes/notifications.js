const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { Notification } = require('../models/Advertisement');
const { Op } = require('sequelize');

router.use(authMiddleware);

// GET /notifications — 获取消息列表
router.get('/', async (req, res, next) => {
  try {
    const limit  = parseInt(req.query.limit)  || 30;
    const offset = parseInt(req.query.offset) || 0;

    const { count, rows } = await Notification.findAndCountAll({
      where: { user_id: req.user.id },
      order: [['created_at', 'DESC']],
      limit, offset,
    });

    res.json({ code: 200, data: { total: count, list: rows, limit, offset } });
  } catch (err) { next(err); }
});

// PATCH /notifications/:id/read — 标记已读
router.patch('/:id/read', async (req, res, next) => {
  try {
    await Notification.update(
      { is_read: true },
      { where: { id: req.params.id, user_id: req.user.id } }
    );
    res.json({ code: 200, message: '已标记为已读' });
  } catch (err) { next(err); }
});

// POST /notifications/read-all — 全部标记已读
router.post('/read-all', async (req, res, next) => {
  try {
    await Notification.update(
      { is_read: true },
      { where: { user_id: req.user.id, is_read: false } }
    );
    res.json({ code: 200, message: '全部已读' });
  } catch (err) { next(err); }
});

// DELETE /notifications/:id — 删除消息
router.delete('/:id', async (req, res, next) => {
  try {
    await Notification.destroy({
      where: { id: req.params.id, user_id: req.user.id },
    });
    res.json({ code: 200, message: '已删除' });
  } catch (err) { next(err); }
});

// DELETE /notifications — 清空所有消息
router.delete('/', async (req, res, next) => {
  try {
    await Notification.destroy({ where: { user_id: req.user.id } });
    res.json({ code: 200, message: '已清空' });
  } catch (err) { next(err); }
});

// GET /notifications/unread-count — 未读数
router.get('/unread-count', async (req, res, next) => {
  try {
    const count = await Notification.count({
      where: { user_id: req.user.id, is_read: false },
    });
    res.json({ code: 200, data: { count } });
  } catch (err) { next(err); }
});

module.exports = router;
