const { Op, fn, col, literal } = require('sequelize');
const { LearningRecord } = require('../models/LearningRecord');

// 防作弊检测规则：
//   1. 单次提交时长超过 24h（86400s）
//   2. 同一用户近1小时内切屏次数超过 50（由客户端上报 switchCount）
//   3. 近24小时累计学习时长超过 24h（极限）

async function check(userId, durationSeconds, switchCount = 0) {
  // 规则1: 单次时长超标
  if (durationSeconds > 86400) {
    return {
      isCheat: true,
      reason: `单次学习时长超过24小时（${durationSeconds}秒）`,
    };
  }

  // 规则2: 切屏次数异常
  if (switchCount > 50) {
    return {
      isCheat: true,
      reason: `切屏次数异常（${switchCount}次/次学习）`,
    };
  }

  // 规则3: 近24小时累计时长超标
  const since = new Date(Date.now() - 24 * 3600 * 1000);
  const result = await LearningRecord.findOne({
    attributes: [[fn('SUM', col('duration_seconds')), 'total']],
    where: {
      user_id: userId,
      started_at: { [Op.gte]: since },
      cheat_flag: false,
    },
  });

  const accumulated = parseInt(result?.get('total') || 0);
  if (accumulated + durationSeconds > 86400 * 1.2) { // 允许20%误差
    return {
      isCheat: true,
      reason: `近24小时累计学习时长超标（已有${accumulated}秒+本次${durationSeconds}秒）`,
    };
  }

  return { isCheat: false, reason: null };
}

// 批量检测：管理员定时任务调用
async function batchCheckAndBan() {
  const { User } = require('../models/User');
  // 查找近1天内作弊记录超过3条的用户
  const [cheaters] = await LearningRecord.sequelize.query(`
    SELECT user_id, COUNT(*) as cheat_count
    FROM learning_records
    WHERE cheat_flag = true
      AND created_at >= NOW() - INTERVAL '1 day'
    GROUP BY user_id
    HAVING COUNT(*) >= 3
  `);

  for (const row of cheaters) {
    await User.update(
      {
        is_banned: true,
        ban_until: new Date(Date.now() + 7 * 24 * 3600 * 1000),
        ban_reason: '检测到学习时长作弊',
      },
      { where: { id: row.user_id, is_banned: false } }
    );
  }

  return cheaters.length;
}

module.exports = { check, batchCheckAndBan };
