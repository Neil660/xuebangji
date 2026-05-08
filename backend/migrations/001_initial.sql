-- ============================================================
-- 学榜记 数据库初始化脚本 v1.0
-- PostgreSQL 16+
-- ============================================================

-- 赛道分类表
CREATE TABLE IF NOT EXISTS tracks (
    id          SERIAL PRIMARY KEY,
    category    VARCHAR(20) NOT NULL,       -- 学生/职场/技能
    name        VARCHAR(50) NOT NULL UNIQUE,
    display_order INT DEFAULT 0,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 初始化赛道数据
INSERT INTO tracks (category, name, display_order) VALUES
('学生', '小学', 1),
('学生', '初中', 2),
('学生', '高中', 3),
('学生', '大学', 4),
('学生', '考研', 5),
('学生', '考公', 6),
('职场', 'IT/互联网', 7),
('职场', '金融', 8),
('职场', '教育', 9),
('职场', '医疗', 10),
('职场', '会计', 11),
('职场', '法律', 12),
('技能', '英语', 13),
('技能', '编程', 14),
('技能', '设计', 15),
('技能', '乐器', 16),
('技能', '健身', 17),
('技能', '其他', 18)
ON CONFLICT (name) DO NOTHING;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id              BIGSERIAL PRIMARY KEY,
    phone           VARCHAR(20) UNIQUE,               -- 手机号（第三方登录可为空）
    password_hash   VARCHAR(255),                     -- bcrypt 哈希
    nickname        VARCHAR(30) NOT NULL UNIQUE,
    avatar_url      VARCHAR(500),
    track_id        INT REFERENCES tracks(id),
    wechat_openid   VARCHAR(100) UNIQUE,
    qq_openid       VARCHAR(100) UNIQUE,
    fcm_token       VARCHAR(500),                     -- Firebase 推送 token
    is_banned       BOOLEAN DEFAULT FALSE,
    ban_until       TIMESTAMPTZ,
    ban_reason      TEXT,
    show_details    BOOLEAN DEFAULT TRUE,             -- 隐私：是否显示学习详情
    show_rank       BOOLEAN DEFAULT TRUE,             -- 隐私：是否显示排名
    daily_goal_sec  INT DEFAULT 0,                    -- 每日目标（秒）
    weekly_goal_sec INT DEFAULT 0,
    monthly_goal_sec INT DEFAULT 0,
    anti_switch_sec INT DEFAULT 30,                   -- 防切屏超时秒数
    show_ads        BOOLEAN DEFAULT TRUE,             -- 是否显示广告
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 用户标签表
CREATE TABLE IF NOT EXISTS user_badges (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_type  VARCHAR(50) NOT NULL,  -- 'discipline_master' | 'persistence_star'
    earned_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, badge_type)
);

-- 科目表
CREATE TABLE IF NOT EXISTS subjects (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        VARCHAR(50) NOT NULL,
    icon        VARCHAR(100) DEFAULT 'book',
    is_default  BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- 学习记录表
CREATE TABLE IF NOT EXISTS learning_records (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subject_id       BIGINT REFERENCES subjects(id) ON DELETE SET NULL,
    subject_name     VARCHAR(50),                      -- 冗余存储，科目删除后仍可查
    started_at       TIMESTAMPTZ NOT NULL,
    ended_at         TIMESTAMPTZ NOT NULL,
    duration_seconds INT NOT NULL CHECK (duration_seconds >= 0 AND duration_seconds <= 86400),
    note             TEXT,
    is_synced        BOOLEAN DEFAULT TRUE,             -- 后端收到即为 true
    cheat_flag       BOOLEAN DEFAULT FALSE,            -- 防作弊标记
    cheat_reason     TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 索引：按用户+时间查询
CREATE INDEX IF NOT EXISTS idx_records_user_started ON learning_records(user_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_records_user_date ON learning_records(user_id, DATE(started_at));

-- 排行榜历史快照表
CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
    id               BIGSERIAL PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    track_id         INT NOT NULL REFERENCES tracks(id),
    period_type      VARCHAR(10) NOT NULL,  -- day|week|month|total
    period_key       VARCHAR(20) NOT NULL,  -- 2026-04-13 | 2026-W15 | 2026-04 | 'total'
    duration_seconds BIGINT NOT NULL DEFAULT 0,
    rank             INT,
    snapshot_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, track_id, period_type, period_key)
);

CREATE INDEX IF NOT EXISTS idx_snapshots_track_period ON leaderboard_snapshots(track_id, period_type, period_key, duration_seconds DESC);

-- 排名变化记录（激励功能）
CREATE TABLE IF NOT EXISTS rank_changes (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    track_id    INT NOT NULL REFERENCES tracks(id),
    period_type VARCHAR(10) NOT NULL,
    old_rank    INT,
    new_rank    INT,
    changed_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 消息通知表
CREATE TABLE IF NOT EXISTS notifications (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(50) NOT NULL,   -- study_remind|rank_change|goal_reached|system
    title       VARCHAR(100) NOT NULL,
    content     TEXT NOT NULL,
    is_read     BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);

-- 广告表
CREATE TABLE IF NOT EXISTS advertisements (
    id               BIGSERIAL PRIMARY KEY,
    advertiser_name  VARCHAR(100) NOT NULL,
    material_image   VARCHAR(500),                -- 实物图片 URL
    material_name    VARCHAR(200) NOT NULL,       -- 实物名称
    period_type      VARCHAR(10) NOT NULL,        -- month|total
    months           VARCHAR(200),                -- JSON 数组，如 ["2026-04","2026-05"]
    is_active        BOOLEAN DEFAULT FALSE,       -- 审核通过后才 true
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 验证码表（手机号登录/注册/忘记密码）
CREATE TABLE IF NOT EXISTS sms_codes (
    id          BIGSERIAL PRIMARY KEY,
    phone       VARCHAR(20) NOT NULL,
    code        VARCHAR(10) NOT NULL,
    purpose     VARCHAR(20) NOT NULL,    -- register|login|reset_password
    is_used     BOOLEAN DEFAULT FALSE,
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_phone ON sms_codes(phone, purpose, is_used, expires_at);

-- 登录记录表
CREATE TABLE IF NOT EXISTS login_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_info TEXT,
    ip_address  VARCHAR(50),
    location    VARCHAR(100),
    logged_at   TIMESTAMPTZ DEFAULT NOW()
);

-- updated_at 自动更新触发器
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER ads_updated_at BEFORE UPDATE ON advertisements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
