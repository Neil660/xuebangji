const fs = require('fs');
require('dotenv').config();

let firebaseInitialized = false;

function initFirebase() {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!serviceAccountPath || !fs.existsSync(serviceAccountPath)) {
    console.log('ℹ️  Firebase 未配置，推送功能不可用（不影响核心功能）');
    return;
  }
  try {
    const admin = require('firebase-admin');
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    firebaseInitialized = true;
    console.log('✅ Firebase Admin 初始化成功');
  } catch (err) {
    console.warn('⚠️  Firebase 初始化失败:', err.message);
  }
}

async function sendPush(fcmToken, title, body, data = {}) {
  if (!firebaseInitialized || !fcmToken) return;
  try {
    const admin = require('firebase-admin');
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
    });
  } catch (err) {
    console.error('FCM 推送失败:', err.message);
  }
}

module.exports = { initFirebase, sendPush };
