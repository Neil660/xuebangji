const moment = require('moment');
const { getRedis } = require('../config/redis');
const { User } = require('../models/User');
const { sequelize } = require('../config/database');

// ── Key 生成规则 ──────────────────────────────────────────────

function periodKey(period, date = new Date()) {
  const m = moment(date);
  switch (period) {
    case 'day':   return m.format('YYYY-MM-DD');
    case 'week':  return m.format('YYYY-[W]WW');
    case 'month': return m.format('YYYY-MM');
    case 'total': return 'total';
    default: throw new Error(`未知 period: ${period}`);
  }
}

function redisKey(trackId, period, date = new Date()) {
  return `leaderboard:${trackId}:${period}:${periodKey(period, date)}`;
}

// ── 添加时长到排行榜 ──────────────────────────────────────────

async function addDuration(userId, trackId, durationSeconds, startedAt) {
  if (!trackId) return;
  const redis = getRedis();
  const date = new Date(startedAt);

  const keys = [
    redisKey(trackId, 'day',   date),
    redisKey(trackId, 'week',  date),
    redisKey(trackId, 'month', date),
    redisKey(trackId, 'total', date),
  ];

  // ZINCRBY 是原子操作，直接累加
  const multi = redis.multi();
  for (const key of keys) {
    multi.zIncrBy(key, durationSeconds, String(userId));
  }
  // 设置 TTL（总榜不过期）
  multi.expire(keys[0], 86400 * 2);      // 日榜 2天
  multi.expire(keys[1], 86400 * 14);     // 周榜 14天
  multi.expire(keys[2], 86400 * 62);     // 月榜 62天
  await multi.exec();
}

// ── 获取排行榜（带用户信息）────────────────────────────────────

async function getLeaderboard(trackId, period, date = new Date(), limit = 100, currentUserId = null) {
  const redis = getRedis();
  const key = redisKey(trackId, period, date);

  // 取前 limit 名（按分数从高到低）
  const entries = await redis.zRangeWithScores(key, 0, limit - 1, { REV: true });

  if (!entries.length) return [];

  const userIds = entries.map((e) => parseInt(e.value));

  // 批量获取用户信息
  const users = await User.findAll({
    where: { id: userIds },
    attributes: ['id', 'nickname', 'avatar_url', 'show_rank', 'show_details'],
  });
  const userMap = new Map(users.map((u) => [u.id, u]));

  return entries.map((entry, idx) => {
    const uid    = parseInt(entry.value);
    const user   = userMap.get(uid);
    const score  = Math.round(parseFloat(entry.score));
    const realSec = Math.floor(score);

    // 隐私：隐藏排名时匿名化（自己看自己除外）
    const isMe = currentUserId && uid === currentUserId;
    const hidden = user && !user.show_rank && !isMe;

    return {
      rank:      idx + 1,
      userId:    uid,
      nickname:  hidden ? '匿名用户' : (user?.nickname || '用户' + uid),
      avatarUrl: hidden ? null : (user?.avatar_url || null),
      durationSec: realSec,
      isHidden:  hidden,
    };
  });
}

// ── 获取用户个人排名 ──────────────────────────────────────────

async function getUserRank(userId, trackId, period, date = new Date()) {
  const redis = getRedis();
  const key = redisKey(trackId, period, date);

  const [rank, score] = await Promise.all([
    redis.zRevRank(key, String(userId)),
    redis.zScore(key, String(userId)),
  ]);

  if (rank === null) return null;

  const myRank = rank + 1;

  // 获取上一名信息（rank-1 对应的分数）
  let aboveDiff = null;
  if (myRank > 1) {
    const aboveEntries = await redis.zRangeWithScores(key, myRank - 2, myRank - 2, { REV: true });
    if (aboveEntries.length) {
      aboveDiff = Math.round(parseFloat(aboveEntries[0].score) - parseFloat(score || 0));
    }
  }

  return {
    rank: myRank,
    durationSec: Math.floor(parseFloat(score || 0)),
    aboveDiffSec: aboveDiff,
  };
}

// ── 获取用户在榜时长 ──────────────────────────────────────────

async function getUserScore(userId, trackId, period, date = new Date()) {
  const redis = getRedis();
  const key = redisKey(trackId, period, date);
  const score = await redis.zScore(key, String(userId));
  return score ? Math.floor(parseFloat(score)) : 0;
}

// ── 排名变化检测（进入前10触发推送）─────────────────────────────

async function checkRankChange(userId, trackId) {
  const redis = getRedis();
  const dayKey = redisKey(trackId, 'day');
  const rank = await redis.zRevRank(dayKey, String(userId));
  if (rank === null) return null;
  return { rank: rank + 1, trackId };
}

// ── 从数据库重建排行榜缓存（启动时调用）───────────────────────

async function rebuildFromDB() {
  const redis = getRedis();
  const { sequelize } = require('../config/database');

  const [records] = await sequelize.query(`
    SELECT lr.user_id, lr.duration_seconds, lr.started_at, u.track_id
    FROM learning_records lr
    JOIN users u ON u.id = lr.user_id
    WHERE lr.cheat_flag = false AND u.track_id IS NOT NULL
  `);

  if (!records.length) {
    console.log('  📊 排行榜: 无历史数据，从零开始');
    return;
  }

  for (const r of records) {
    const date = new Date(r.started_at);
    const keys = [
      redisKey(r.track_id, 'day', date),
      redisKey(r.track_id, 'week', date),
      redisKey(r.track_id, 'month', date),
      redisKey(r.track_id, 'total', date),
    ];

    const multi = redis.multi();
    for (const key of keys) {
      multi.zIncrBy(key, r.duration_seconds, String(r.user_id));
    }
    multi.expire(redisKey(r.track_id, 'day', date), 86400 * 2);
    multi.expire(redisKey(r.track_id, 'week', date), 86400 * 14);
    multi.expire(redisKey(r.track_id, 'month', date), 86400 * 62);
    await multi.exec();
  }

  console.log(`  📊 排行榜: 从数据库重建完成 (${records.length}条记录)`);
}

module.exports = {
  addDuration,
  getLeaderboard,
  getUserRank,
  getUserScore,
  checkRankChange,
  rebuildFromDB,
  periodKey,
  redisKey,
};
