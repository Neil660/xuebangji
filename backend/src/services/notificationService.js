const { sendPush } = require('../config/firebase');
const { Notification } = require('../models/Advertisement');

// ── 发送推送 + 写入数据库 ─────────────────────────────────────

async function push(user, type, { title, body, data = {} }) {
  // 写入数据库通知
  await Notification.create({
    user_id: user.id,
    type,
    title,
    content: body,
  });

  // FCM 推送
  if (user.fcm_token) {
    await sendPush(user.fcm_token, title, body, data);
  }
}

// ── 发送学习目标提醒 ──────────────────────��───────────────────

async function sendGoalReminder(userId, fcmToken, completed, total) {
  const pct = (completed / total * 100).toFixed(0);
  const remaining = Math.max(0, total - completed);

  if (pct >= 80 && pct < 100) {
    const min = Math.ceil(remaining / 60);
    await push(
      { id: userId, fcm_token: fcmToken },
      'goal_remind',
      {
        title: '快完成今日目标了！',
        body: `距离今日目标还有${min}分钟，加把劲！`,
        data: { type: 'goal_remind' },
      }
    );
  } else if (pct >= 100) {
    await push(
      { id: userId, fcm_token: fcmToken },
      'goal_reached',
      {
        title: '今日学习目标已达成！',
        body: '恭喜你完成了今日学习目标！继续保持！',
        data: { type: 'goal_reached' },
      }
    );
  }
}

module.exports = { push, sendGoalReminder };
