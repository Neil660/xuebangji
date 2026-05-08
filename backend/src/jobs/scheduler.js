const cron = require('node-cron');
const moment = require('moment');
const { sequelize } = require('../config/database');
const { getRedis } = require('../config/redis');
const { User } = require('../models/User');
const leaderboardService = require('../services/leaderboardService');
const antiCheatService = require('../services/antiCheatService');
const notificationService = require('../services/notificationService');

// ── 每10分钟：检测排名变化并推送通知 ────────────────────────

cron.schedule('*/10 * * * *', async () => {
  console.log('[Scheduler] 检测排名变化...');
  try {
    await _detectRankChanges();
  } catch (err) {
    console.error('[Scheduler] 排名变化检测失败:', err.message);
  }
});

// ── 每天凌晨0点：日榜归档、检查打卡达人徽章 ─────────────────

cron.schedule('0 0 * * *', async () => {
  console.log('[Scheduler] 日榜归档...');
  try {
    await _archiveDailyLeaderboard();
    await _checkBadges();
    await antiCheatService.batchCheckAndBan();
  } catch (err) {
    console.error('[Scheduler] 日榜归档失败:', err.message);
  }
});

// ── 每周一凌晨0:05：周榜归档 ─────────────────────────────────

cron.schedule('5 0 * * 1', async () => {
  console.log('[Scheduler] 周榜归档...');
  try {
    await _archiveLeaderboard('week');
  } catch (err) {
    console.error('[Scheduler] 周榜归档失败:', err.message);
  }
});

// ── 每月1日凌晨0:10：月榜归档 ────────────────────────────────

cron.schedule('10 0 1 * *', async () => {
  console.log('[Scheduler] 月榜归档...');
  try {
    await _archiveLeaderboard('month');
  } catch (err) {
    console.error('[Scheduler] 月榜归档失败:', err.message);
  }
});

// ── 归档函数 ─────────────────────────────────────────────────

async function _archiveDailyLeaderboard() {
  const yesterday = moment().subtract(1, 'day');
  await _archiveLeaderboardForDate('day', yesterday.toDate());
}

async function _archiveLeaderboard(period) {
  const now = new Date();
  await _archiveLeaderboardForDate(period, now);
}

async function _archiveLeaderboardForDate(period, date) {
  const redis = getRedis();
  const { Track } = require('../models/Track');

  const tracks = await Track.findAll({ where: { is_active: true } });
  const pKey = leaderboardService.periodKey(period, date);

  for (const track of tracks) {
    const key = leaderboardService.redisKey(track.id, period, date);
    const entries = await redis.zRangeWithScores(key, 0, -1, { REV: true });

    if (!entries.length) continue;

    // 批量 upsert 快照到 PostgreSQL
    const snapshots = entries.map((e, idx) => ({
      user_id: parseInt(e.value),
      track_id: track.id,
      period_type: period,
      period_key: pKey,
      duration_seconds: Math.floor(parseFloat(e.score)),
      rank: idx + 1,
      snapshot_at: new Date(),
    }));

    await sequelize.query(`
      INSERT INTO leaderboard_snapshots
        (user_id, track_id, period_type, period_key, duration_seconds, rank, snapshot_at)
      VALUES ${snapshots.map(() => '(?,?,?,?,?,?,?)').join(',')}
      ON CONFLICT (user_id, track_id, period_type, period_key)
      DO UPDATE SET duration_seconds = EXCLUDED.duration_seconds,
                    rank = EXCLUDED.rank,
                    snapshot_at = EXCLUDED.snapshot_at
    `, {
      replacements: snapshots.flatMap((s) => [
        s.user_id, s.track_id, s.period_type, s.period_key,
        s.duration_seconds, s.rank, s.snapshot_at,
      ]),
    });
  }
}

// ── 排名变化检测与推送 ────────────────────────────────────────

async function _detectRankChanges() {
  // 简单实现：对日榜 top 200 用户进行排名快照对比
  const redis = getRedis();
  const { Track } = require('../models/Track');
  const tracks = await Track.findAll({ where: { is_active: true } });

  for (const track of tracks) {
    const key = leaderboardService.redisKey(track.id, 'day');
    const snapshotKey = `rank_snapshot:${track.id}:day`;

    const current = await redis.zRangeWithScores(key, 0, 199, { REV: true });
    const previousRaw = await redis.get(snapshotKey);

    if (previousRaw) {
      const previous = JSON.parse(previousRaw);
      const prevMap = new Map(previous.map((e) => [e.value, e.rank]));

      for (let i = 0; i < current.length; i++) {
        const uid = current[i].value;
        const newRank = i + 1;
        const oldRank = prevMap.get(uid);

        if (oldRank && oldRank !== newRank) {
          const user = await User.findByPk(parseInt(uid), {
            attributes: ['id', 'fcm_token', 'nickname'],
          });
          if (!user?.fcm_token) continue;

          const diff = oldRank - newRank;
          if (diff > 0) {
            await notificationService.push(user, 'rank_change', {
              title: '排名上升！',
              body: `你在${track.name}赛道日榜上升了${diff}名，当前排名第${newRank}名！`,
              data: { trackId: String(track.id), period: 'day', rank: String(newRank) },
            });
          } else if (diff < -2) {
            // 下降超过2名才推送，避免频繁打扰
            await notificationService.push(user, 'rank_change', {
              title: '排名下降',
              body: `你在${track.name}赛道被超越，当前排名第${newRank}名，加油！`,
              data: { trackId: String(track.id), period: 'day', rank: String(newRank) },
            });
          }
        }
      }
    }

    // 保存当前快照（带排名）
    const snapshot = current.map((e, i) => ({ value: e.value, rank: i + 1 }));
    await redis.setEx(snapshotKey, 700, JSON.stringify(snapshot)); // 略超10分钟
  }
}

// ── 勋章检测 ─────────────────────────────────────────────────

async function _checkBadges() {
  const { UserBadge } = require('../models/UserBadge');
  const { Track } = require('../models/Track');
  const tracks = await Track.findAll({ where: { is_active: true } });

  for (const track of tracks) {
    // 连续7天进入日榜前10 → "自律达人"
    const yesterday = moment().subtract(1, 'day');
    const keys = [];
    for (let i = 0; i < 7; i++) {
      keys.push(leaderboardService.redisKey(
        track.id, 'day', moment().subtract(i, 'days').toDate()
      ));
    }

    // 找连续7天都在前10的用户
    const redis = getRedis();
    const top10Sets = await Promise.all(
      keys.map((k) => redis.zRange(k, 0, 9, { REV: true }))
    );

    const commonUsers = top10Sets.reduce((acc, set) => {
      return set.length ? acc.filter((uid) => set.includes(uid)) : acc;
    }, top10Sets[0] || []);

    for (const uid of commonUsers) {
      await sequelize.query(`
        INSERT INTO user_badges (user_id, badge_type, earned_at)
        VALUES (?, 'discipline_master', NOW())
        ON CONFLICT (user_id, badge_type) DO NOTHING
      `, { replacements: [parseInt(uid)] });
    }
  }
}

console.log('✅ 定时任务已启动');
module.exports = {};