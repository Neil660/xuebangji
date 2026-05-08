# 学榜记 - 学习时长记录与同赛道排行榜

一款专注于学习时长精准记录、同赛道用户排行榜PK的轻量化学习工具，以"攀比激励"为核心驱动力，帮助用户提升学习自律性。

---

## 快速启动

### 环境要求

| 依赖 | 版本 |
|------|------|
| Node.js | >= 18.0.0 |
| MySQL | 8.0+ |
| npm | >= 9.0.0 |

### 1. 创建数据库

```sql
CREATE DATABASE IF NOT EXISTS xuebangji CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2. 配置环境变量

```bash
cd backend
cp .env.example .env   # 已有 .env 则跳过
```

编辑 `.env` 填入你的 MySQL 连接信息：

```env
DB_HOST=localhost
DB_PORT=3306
DB_NAME=xuebangji
DB_USER=root
DB_PASSWORD=你的密码
```

### 3. 安装依赖 & 启动

```bash
cd backend
npm install
npm start
```

启动后访问：**http://localhost:3000**

### 停止 / 重启

```bash
npm stop        # 优雅关闭（SIGTERM）
npm restart     # 关闭后重新启动
```

服务启动时自动写入 `.server.pid` 文件，`npm stop` 读取PID发送关闭信号，等待HTTP连接关闭后自动退出，无需手动 taskkill。

---

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| 后端框架 | Express.js 4.x | RESTful API |
| ORM | Sequelize 6.x | 数据库操作 |
| 数据库 | MySQL 8.0 | 主数据存储 |
| 缓存 | 内存实现 (开发) / Redis (生产) | 排行榜实时排序 |
| 认证 | JWT (access + refresh token) | 双token无感刷新 |
| 密码加密 | bcryptjs | 12轮哈希 |
| 定时任务 | node-cron | 排行榜归档/勋章检测 |
| 推送 | Firebase Cloud Messaging | 排名变化/目标提醒 |
| 限流 | express-rate-limit | 防刷保护 |
| 移动端 | Flutter 3.x + Riverpod | Android/iOS 双端 |
| Web前端 | 原生 HTML/CSS/JS (SPA) | 浏览器测试与使用 |

---

## 项目结构

```
xuebangji/
├── README.md
├── 学习时长记录与同赛道排行榜APP详细说明（安卓+苹果双端） (1).md
├── backend/
│   ├── package.json
│   ├── .env                          # 环境配置
│   ├── public/                       # Web前端静态文件
│   │   ├── index.html                # SPA入口
│   │   ├── css/style.css             # 样式
│   │   └── js/
│   │       ├── api.js                # API客户端
│   │       └── app.js                # 主应用逻辑
│   ├── migrations/
│   │   └── 001_initial.sql           # 数据库初始化SQL
│   └── src/
│       ├── app.js                    # Express入口（含优雅关闭）
│       ├── stop.js                   # npm stop 优雅关闭脚本
│       ├── config/
│       │   ├── database.js           # 数据库连接
│       │   ├── redis.js              # 缓存（内存/Redis）
│       │   └── firebase.js           # FCM推送
│       ├── middleware/
│       │   ├── auth.js               # JWT认证中间件
│       │   ├── adminAuth.js          # 管理员权限中间件
│       │   ├── errorHandler.js       # 全局错误处理
│       │   └── rateLimiter.js        # 限流中间件
│       ├── models/
│       │   ├── User.js               # 用户
│       │   ├── Track.js              # 赛道
│       │   ├── Subject.js            # 学习科目
│       │   ├── LearningRecord.js     # 学习记录
│       │   ├── Advertisement.js      # 广告+通知+勋章
│       │   └── Auth.js               # 验证码+登录日志
│       ├── routes/
│       │   ├── auth.js               # 注册/登录/验证码
│       │   ├── users.js              # 个人信息/设置
│       │   ├── subjects.js           # 科目CRUD
│       │   ├── records.js            # 学习记录/统计/趋势
│       │   ├── leaderboard.js        # 排行榜
│       │   ├── notifications.js      # 消息通知
│       │   ├── advertisements.js     # 广告查询
│       │   └── admin.js              # 管理员API（广告CRUD/用户管理）
│       ├── services/
│       │   ├── authService.js        # 认证逻辑
│       │   ├── leaderboardService.js # 排行榜排序
│       │   ├── antiCheatService.js   # 防作弊检测
│       │   └── notificationService.js# 推送服务
│       └── jobs/
│           └── scheduler.js          # 定时任务
└── mobile/                           # Flutter移动端
    └── lib/
        ├── main.dart
        ├── core/                     # 主题/API/数据库/路由
        └── features/                 # 功能模块
            ├── auth/                 # 登录注册
            ├── home/                 # 首页计时器
            ├── records/              # 学习记录
            ├── leaderboard/          # 排行榜
            ├── profile/              # 个人中心
            └── notifications/        # 消息通知
```

---

## API 接口一览

### 认证 `/api/v1/auth`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/tracks` | 获取赛道列表 | 否 |
| POST | `/sms` | 发送验证码 | 否 |
| POST | `/register` | 注册 | 否 |
| POST | `/login` | 密码登录 | 否 |
| POST | `/login-sms` | 验证码登录 | 否 |
| POST | `/reset-password` | 重置密码 | 否 |
| POST | `/refresh` | 刷新Token | 否 |

### 用户 `/api/v1/users`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/me` | 获取个人信息 | 是 |
| PATCH | `/me` | 修改个人信息 | 是 |
| POST | `/me/password` | 修改密码 | 是 |
| POST | `/me/avatar` | 上传头像 | 是 |
| GET | `/me/login-logs` | 登录记录 | 是 |
| GET | `/me/stats` | 学习汇总数据 | 是 |

### 科目 `/api/v1/subjects`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/` | 科目列表 | 是 |
| POST | `/` | 添加科目 | 是 |
| PATCH | `/:id` | 编辑科目 | 是 |
| DELETE | `/:id` | 删除科目 | 是 |

### 学习记录 `/api/v1/records`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | `/` | 提交学习记录 | 是 |
| GET | `/` | 查询记录列表 | 是 |
| GET | `/stats` | 时长统计 | 是 |
| GET | `/trend` | 学习趋势 | 是 |
| DELETE | `/:id` | 删除记录 | 是 |

### 排行榜 `/api/v1/leaderboard`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/` | 排行榜（日/周/月/总） | 是 |
| GET | `/my-rank` | 个人排名 | 是 |
| GET | `/user/:userId` | 查看用户学习明细 | 是 |

### 通知 `/api/v1/notifications`

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/` | 消息列表 | 是 |
| GET | `/unread-count` | 未读数 | 是 |
| PATCH | `/:id/read` | 标记已读 | 是 |
| POST | `/read-all` | 全部已读 | 是 |
| DELETE | `/:id` | 删除消息 | 是 |
| DELETE | `/` | 清空消息 | 是 |

---

## 核心功能

### 1. 学习计时器
- 开始/暂停/继续/结束学习
- 支持选择学习科目，可设默认科目
- 结束后填写学习备注（可选）
- 实时显示今日目标完成进度

### 2. 用户系统
- 手机号注册/登录，开发模式固定验证码 `123456`
- 个人资料编辑：昵称、头像URL、性别、生日、赛道
- 隐私设置：隐藏学习详情/排行榜排名
- 勋章系统：自律达人、坚持之星

### 3. 学习记录
- 按今日/昨日/近7天/近30天筛选
- 今日/本周/本月/累计时长统计
- 科目分布饼图、学习趋势折线图
- 记录同步状态显示

### 4. 同赛道排行榜
- 日榜/周榜/月榜/总榜切换
- 基于内存Sorted Set实时排序，启动时从MySQL自动重建缓存
- 前3名金银铜牌展示
- 4-9名、10-50名、51-100名分段标识
- 个人排名卡（距上一名差距）
- 新用户需30分钟以上方可上榜
- 可查看其他用户脱敏学习明细

### 5. 管理员模式
- `is_admin` 字段控制，数据库直接设置
- 广告管理：添加/审核/上下线/删除
- 用户管理：查看列表、设置管理员

### 6. 赛道系统
18个预设赛道，三大分类：
- **学生**：小学/初中/高中/大学/考研/考公
- **职场**：IT互联网/金融/教育/医疗/会计/法律
- **技能**：英语/编程/设计/乐器/健身/其他

### 7. 防作弊
- 单次时长 ≤ 24小时
- 切屏次数监控
- 24小时累计时长检测
- 自动封禁7天/永久

### 8. 勋章激励
- 连续7天日榜前10 → "自律达人"
- 连续30天完成目标 → "坚持之星"

### 9. 广告系统
- 仅月榜/总榜展示
- 支持实物赞助广告
- 用户可自主关闭

### 10. 离线支持
- 本地优先记录
- 联网后自动同步
- 离线可查看历史数据

---

## 开发说明

### 开发模式验证码

开发环境下（`NODE_ENV=development`），短信验证码固定为 `123456`，无需真实短信服务。

### 日志输出

启动后终端会实时输出：
- `[SQL]` — 每条SQL语句
- `✅/❌` — API请求方法、URL、状态码、耗时
- `📥 请求体` — POST/PATCH/PUT请求参数
- `📤 响应` — 4xx/5xx错误响应内容

### 移动端

移动端基于 Flutter 开发，支持 Android 8.0+ 和 iOS 13.0+。详见 `mobile/` 目录。

---

## 赛道扩展

通过后台数据库直接添加即可，无需修改代码：

```sql
INSERT INTO tracks (category, name, display_order, is_active) 
VALUES ('技能', '摄影', 19, 1);
```

---

## License

Copyright © 2026 学榜记

如果有想法想开发什么软件，可以联系我哦：1150842880@qq.com
