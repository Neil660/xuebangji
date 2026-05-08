/**
 * npm stop — 优雅关闭学榜记服务
 * 用法: npm stop
 */

const fs = require('fs');
const path = require('path');

const PID_FILE = path.join(__dirname, '..', '.server.pid');

if (!fs.existsSync(PID_FILE)) {
  console.log('⚠️  未找到运行中的服务（.server.pid 不存在）');
  console.log('   如果服务仍在运行，请手动查找端口进程：');
  console.log('   netstat -ano | findstr :3000');
  process.exit(1);
}

const pid = parseInt(fs.readFileSync(PID_FILE, 'utf8').trim());

if (!pid || isNaN(pid)) {
  console.log('⚠️  PID 文件内容无效，清理中...');
  fs.unlinkSync(PID_FILE);
  process.exit(1);
}

// 尝试发送 SIGTERM
try {
  process.kill(pid, 'SIGTERM');
  console.log(`✅ 已发送关闭信号到 PID: ${pid}`);
  console.log('   服务正在优雅关闭...');

  // 等待进程退出
  let attempts = 0;
  const check = setInterval(() => {
    try {
      process.kill(pid, 0); // 检查进程是否存在
      attempts++;
      if (attempts > 10) {
        clearInterval(check);
        console.log('⚠️  进程未响应，尝试强制终止...');
        try {
          process.kill(pid, 'SIGKILL');
          console.log('✅ 已强制终止');
        } catch {}
        try { fs.unlinkSync(PID_FILE); } catch {}
        process.exit(0);
      }
    } catch {
      // 进程已退出
      clearInterval(check);
      console.log('✅ 服务已关闭');
      try { fs.unlinkSync(PID_FILE); } catch {}
      process.exit(0);
    }
  }, 500);
} catch (err) {
  console.error('❌ 关闭失败:', err.message);
  console.log('   请手动操作：taskkill //PID ' + pid + ' //F');
  try { fs.unlinkSync(PID_FILE); } catch {}
  process.exit(1);
}
