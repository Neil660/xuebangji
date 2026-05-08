require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const { connectDB } = require('./config/database');
const { connectRedis } = require('./config/redis');
const { initFirebase } = require('./config/firebase');
const { defaultLimiter } = require('./middleware/rateLimiter');
const errorHandler = require('./middleware/errorHandler');

// 路由
const authRoutes         = require('./routes/auth');
const userRoutes         = require('./routes/users');
const subjectRoutes      = require('./routes/subjects');
const recordRoutes       = require('./routes/records');
const leaderboardRoutes  = require('./routes/leaderboard');
const leaderboardService = require('./services/leaderboardService');
const notificationRoutes = require('./routes/notifications');
const adRoutes           = require('./routes/advertisements');
const adminRoutes        = require('./routes/admin');

const app = express();

// ── 基础中间件 ──────────────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: false, // 允许加载 Web 前端脚本
}));
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
}));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// ── 实时请求日志（调试用）──────────────────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  const origJson = res.json.bind(res);
  res.json = function(body) {
    const duration = Date.now() - start;
    const url = req.originalUrl;
    if (url.startsWith('/api/')) {
      const method = req.method;
      const status = res.statusCode;
      const icon = status >= 400 ? '❌' : status >= 300 ? '⚠️' : '✅';
      console.log(`  ${icon} [${method}] ${url} → ${status} (${duration}ms)`);
      if (req.method !== 'GET' && Object.keys(req.body || {}).length > 0) {
        console.log(`    📥 请求体:`, JSON.stringify(req.body, null, 2).substring(0, 300));
      }
      if (status >= 400 && body) {
        console.log(`    📤 响应:`, JSON.stringify(body).substring(0, 300));
      }
    }
    return origJson(body);
  };
  next();
});

app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// ── Web 前端静态文件 ────────────────────────────────────────
app.use(express.static(path.join(__dirname, '..', 'public')));

// ── 全局限流 ────────────────────────────────────────────────
app.use(defaultLimiter);

// ── 健康检查 ────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date() }));

// ── 业务路由 ─────────────────────────────────────────────
app.use('/api/v1/auth',          authRoutes);
app.use('/api/v1/users',         userRoutes);
app.use('/api/v1/subjects',      subjectRoutes);
app.use('/api/v1/records',       recordRoutes);
app.use('/api/v1/leaderboard',   leaderboardRoutes);
app.use('/api/v1/notifications', notificationRoutes);
app.use('/api/v1/advertisements',adRoutes);
app.use('/api/v1/admin',        adminRoutes);

// ── SPA fallback ────────────────────────────────────────────
app.get(/^\/(?!api\/|uploads\/|health).*/, (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

// ── 404 API ─────────────────────────────────────────────────
app.use('/api', (req, res) => res.status(404).json({ code: 404, message: '接口不存在' }));

// ── 全局错误处理 ────────────────────────────────────────────
app.use(errorHandler);

// ── PID 文件（用于 npm stop 优雅关闭）──────────────────────
const PID_FILE = path.join(__dirname, '..', '.server.pid');
const fs = require('fs');

// ── 启动 ────────────────────────────────────────────────────
async function bootstrap() {
  await connectDB();
  await connectRedis();
  await leaderboardService.rebuildFromDB();
  initFirebase();

  // 启动定时任务
  let scheduler = null;
  try {
    scheduler = require('./jobs/scheduler');
  } catch (err) {
    console.warn('⚠️  定时任务启动失败（非关键）:', err.message);
  }

  const PORT = parseInt(process.env.PORT) || 3000;
  const server = app.listen(PORT, () => {
    // 写入 PID 文件
    fs.writeFileSync(PID_FILE, String(process.pid));
    console.log(`🚀 学榜记服务已启动：http://localhost:${PORT}`);
    console.log(`📱 Web前端：http://localhost:${PORT}`);
    console.log(`📄 环境：${process.env.NODE_ENV || 'development'}`);
    console.log(`📋 PID: ${process.pid}  →  \`npm stop\` 优雅关闭`);
  });

  // 优雅关闭
  const shutdown = (signal) => {
    console.log(`\n🛑 收到 ${signal} 信号，正在优雅关闭...`);
    server.close(() => {
      console.log('✅ HTTP 服务已关闭');
      try { fs.unlinkSync(PID_FILE); } catch {}
      process.exit(0);
    });
    // 超时强制退出
    setTimeout(() => {
      console.warn('⚠️  超时，强制退出');
      process.exit(1);
    }, 5000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT',  () => shutdown('SIGINT'));
}

bootstrap().catch((err) => {
  console.error('启动失败:', err);
  process.exit(1);
});

module.exports = app;
