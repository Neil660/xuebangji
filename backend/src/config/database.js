const { Sequelize } = require('sequelize');
require('dotenv').config();

const sequelize = new Sequelize(
  process.env.DB_NAME || 'xuebangji',
  process.env.DB_USER || 'root',
  process.env.DB_PASSWORD || '',
  {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 3306,
    dialect: 'mysql',
    charset: 'utf8mb4',
    collate: 'utf8mb4_unicode_ci',
    dialectOptions: {
      charset: 'utf8mb4',
    },
    logging: (msg) => {
      // 实时输出SQL日志到控制台
      if (!msg.includes('SELECT 1+1')) {
        console.log(`  [SQL] ${msg}`);
      }
    },
    pool: {
      max: 10,
      min: 2,
      acquire: 30000,
      idle: 10000,
    },
    define: {
      underscored: true,
      timestamps: true,
    },
  }
);

async function connectDB() {
  try {
    await sequelize.authenticate();
    console.log('✅ MySQL 连接成功:', process.env.DB_NAME);

    // 自动同步模型（开发模式）
    if (process.env.NODE_ENV !== 'production') {
      await sequelize.sync({ alter: false });
      console.log('✅ 数据库模型同步完成');
    }

    // 初始化赛道数据
    await seedTracks();
  } catch (err) {
    console.error('❌ 数据库初始化失败:', err.message);
    process.exit(1);
  }
}

async function seedTracks() {
  const { Track } = require('../models/Track');
  const count = await Track.count();
  if (count === 0) {
    const tracks = [
      { category: '学生', name: '小学', display_order: 1, is_active: true },
      { category: '学生', name: '初中', display_order: 2, is_active: true },
      { category: '学生', name: '高中', display_order: 3, is_active: true },
      { category: '学生', name: '大学', display_order: 4, is_active: true },
      { category: '学生', name: '考研', display_order: 5, is_active: true },
      { category: '学生', name: '考公', display_order: 6, is_active: true },
      { category: '职场', name: 'IT/互联网', display_order: 7, is_active: true },
      { category: '职场', name: '金融', display_order: 8, is_active: true },
      { category: '职场', name: '教育', display_order: 9, is_active: true },
      { category: '职场', name: '医疗', display_order: 10, is_active: true },
      { category: '职场', name: '会计', display_order: 11, is_active: true },
      { category: '职场', name: '法律', display_order: 12, is_active: true },
      { category: '技能', name: '英语', display_order: 13, is_active: true },
      { category: '技能', name: '编程', display_order: 14, is_active: true },
      { category: '技能', name: '设计', display_order: 15, is_active: true },
      { category: '技能', name: '乐器', display_order: 16, is_active: true },
      { category: '技能', name: '健身', display_order: 17, is_active: true },
      { category: '技能', name: '其他', display_order: 18, is_active: true },
    ];
    await Track.bulkCreate(tracks);
    console.log('✅ 赛道数据初始化完成');
  }
}

module.exports = { sequelize, connectDB };
