const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { Advertisement } = require('../models/Advertisement');

router.use(authMiddleware);

// GET /advertisements — 获取有效广告列表
router.get('/', async (req, res, next) => {
  try {
    const { period } = req.query;
    const where = { is_active: true };
    if (period) where.period_type = period;

    const ads = await Advertisement.findAll({
      where,
      order: [['created_at', 'DESC']],
      limit: 10,
    });
    res.json({ code: 200, data: ads });
  } catch (err) { next(err); }
});

module.exports = router;
