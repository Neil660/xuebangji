const express = require('express');
const { body, validationResult } = require('express-validator');
const router = express.Router();

const authMiddleware = require('../middleware/auth');
const { Subject } = require('../models/Subject');

router.use(authMiddleware);

function validate(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ code: 400, message: errors.array()[0].msg });
    return false;
  }
  return true;
}

// GET /subjects — 获取当前用户的科目列表
router.get('/', async (req, res, next) => {
  try {
    const subjects = await Subject.findAll({
      where: { user_id: req.user.id },
      order: [['created_at', 'ASC']],
    });
    res.json({ code: 200, data: subjects });
  } catch (err) { next(err); }
});

// POST /subjects — 新增科目
router.post('/', [
  body('name').isLength({ min: 1, max: 50 }).withMessage('科目名称不能为空'),
  body('icon').optional().isLength({ max: 100 }),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    const existing = await Subject.findOne({
      where: { user_id: req.user.id, name: req.body.name.trim() },
    });
    if (existing) return res.status(409).json({ code: 409, message: '科目名称已存在' });

    const subject = await Subject.create({
      user_id: req.user.id,
      name: req.body.name.trim(),
      icon: req.body.icon || 'book',
    });
    res.status(201).json({ code: 201, data: subject });
  } catch (err) { next(err); }
});

// PUT /subjects/:id — 修改科目
router.put('/:id', [
  body('name').optional().isLength({ min: 1, max: 50 }),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    const subject = await Subject.findOne({
      where: { id: req.params.id, user_id: req.user.id },
    });
    if (!subject) return res.status(404).json({ code: 404, message: '科目不存在' });

    const updates = {};
    if (req.body.name) updates.name = req.body.name.trim();
    if (req.body.icon) updates.icon = req.body.icon;
    if (req.body.is_default !== undefined) {
      // 取消其他默认
      if (req.body.is_default) {
        await Subject.update(
          { is_default: false },
          { where: { user_id: req.user.id } }
        );
      }
      updates.is_default = req.body.is_default;
    }

    await subject.update(updates);
    res.json({ code: 200, data: subject });
  } catch (err) { next(err); }
});

// DELETE /subjects/:id — 删除科目（记录不受影响）
router.delete('/:id', async (req, res, next) => {
  try {
    const subject = await Subject.findOne({
      where: { id: req.params.id, user_id: req.user.id },
    });
    if (!subject) return res.status(404).json({ code: 404, message: '科目不存在' });

    await subject.destroy();
    res.json({ code: 200, message: '科目已删除，相关学习记录不受影响' });
  } catch (err) { next(err); }
});

module.exports = router;
