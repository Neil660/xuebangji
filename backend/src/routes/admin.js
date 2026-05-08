const express = require('express');
const { body, query, validationResult } = require('express-validator');
const router = express.Router();

const authMiddleware = require('../middleware/auth');
const adminMiddleware = require('../middleware/adminAuth');
const { Advertisement } = require('../models/Advertisement');
const { User } = require('../models/User');

router.use(authMiddleware);
router.use(adminMiddleware);

function validate(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({ code: 400, message: errors.array()[0].msg });
    return false;
  }
  return true;
}

// ── GET /admin/ads — 广告列表（含未审核） ──────────────────────

router.get('/ads', async (req, res, next) => {
  try {
    const ads = await Advertisement.findAll({
      order: [['created_at', 'DESC']],
    });
    res.json({ code: 200, data: ads });
  } catch (err) { next(err); }
});

// ── POST /admin/ads — 创建广告 ────────────────────────────────

router.post('/ads', [
  body('advertiserName').notEmpty().withMessage('广告商名称不能为空'),
  body('materialName').notEmpty().withMessage('实物名称不能为空'),
  body('materialImage').optional().isURL().withMessage('图片URL格式错误'),
  body('periodType').isIn(['month', 'total']).withMessage('广告类型：month 或 total'),
  body('months').optional().isString(),
  body('isActive').optional().isBoolean(),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    const ad = await Advertisement.create({
      advertiser_name: req.body.advertiserName,
      material_name: req.body.materialName,
      material_image: req.body.materialImage || null,
      period_type: req.body.periodType,
      months: req.body.months || null,
      is_active: req.body.isActive !== undefined ? req.body.isActive : false,
    });
    res.status(201).json({ code: 201, data: ad });
  } catch (err) { next(err); }
});

// ── PATCH /admin/ads/:id — 编辑/审核广告 ──────────────────────

router.patch('/ads/:id', async (req, res, next) => {
  try {
    const ad = await Advertisement.findByPk(req.params.id);
    if (!ad) return res.status(404).json({ code: 404, message: '广告不存在' });

    const updates = {};
    if (req.body.advertiserName !== undefined) updates.advertiser_name = req.body.advertiserName;
    if (req.body.materialName !== undefined) updates.material_name = req.body.materialName;
    if (req.body.materialImage !== undefined) updates.material_image = req.body.materialImage;
    if (req.body.periodType !== undefined) updates.period_type = req.body.periodType;
    if (req.body.months !== undefined) updates.months = req.body.months;
    if (req.body.isActive !== undefined) updates.is_active = req.body.isActive;

    await ad.update(updates);
    res.json({ code: 200, data: ad });
  } catch (err) { next(err); }
});

// ── DELETE /admin/ads/:id — 删除广告 ──────────────────────────

router.delete('/ads/:id', async (req, res, next) => {
  try {
    const ad = await Advertisement.findByPk(req.params.id);
    if (!ad) return res.status(404).json({ code: 404, message: '广告不存在' });
    await ad.destroy();
    res.json({ code: 200, message: '广告已删除' });
  } catch (err) { next(err); }
});

// ── PATCH /admin/users/:id/admin — 设置/取消管理员 ────────────

router.patch('/users/:id/admin', [
  body('isAdmin').isBoolean().withMessage('isAdmin 必填'),
], async (req, res, next) => {
  if (!validate(req, res)) return;
  try {
    const user = await User.findByPk(req.params.id);
    if (!user) return res.status(404).json({ code: 404, message: '用户不存在' });
    await user.update({ is_admin: req.body.isAdmin });
    res.json({ code: 200, message: req.body.isAdmin ? '已设为管理员' : '已取消管理员' });
  } catch (err) { next(err); }
});

// ── GET /admin/users — 用户列表（管理用） ──────────────────────

router.get('/users', [
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('offset').optional().isInt({ min: 0 }),
], async (req, res, next) => {
  const limit = parseInt(req.query.limit) || 30;
  const offset = parseInt(req.query.offset) || 0;
  try {
    const { count, rows } = await User.findAndCountAll({
      attributes: { exclude: ['password_hash'] },
      order: [['created_at', 'DESC']],
      limit,
      offset,
    });
    res.json({ code: 200, data: { total: count, list: rows, limit, offset } });
  } catch (err) { next(err); }
});

module.exports = router;
