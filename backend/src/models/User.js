const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const User = sequelize.define('User', {
  id: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  phone: { type: DataTypes.STRING(20), unique: true },
  password_hash: { type: DataTypes.STRING(255) },
  nickname: { type: DataTypes.STRING(30), allowNull: false, unique: true },
  avatar_url: { type: DataTypes.STRING(500) },
  gender: { type: DataTypes.ENUM('male', 'female', 'secret'), defaultValue: 'secret' },
  birthday: { type: DataTypes.DATEONLY },
  track_id: { type: DataTypes.INTEGER },
  wechat_openid: { type: DataTypes.STRING(100), unique: true },
  qq_openid: { type: DataTypes.STRING(100), unique: true },
  fcm_token: { type: DataTypes.STRING(500) },
  is_banned: { type: DataTypes.BOOLEAN, defaultValue: false },
  ban_until: { type: DataTypes.DATE },
  ban_reason: { type: DataTypes.TEXT },
  show_details: { type: DataTypes.BOOLEAN, defaultValue: true },
  show_rank: { type: DataTypes.BOOLEAN, defaultValue: true },
  daily_goal_sec: { type: DataTypes.INTEGER, defaultValue: 0 },
  weekly_goal_sec: { type: DataTypes.INTEGER, defaultValue: 0 },
  monthly_goal_sec: { type: DataTypes.INTEGER, defaultValue: 0 },
  anti_switch_sec: { type: DataTypes.INTEGER, defaultValue: 30 },
  show_ads: { type: DataTypes.BOOLEAN, defaultValue: true },
  is_admin: { type: DataTypes.BOOLEAN, defaultValue: false },
}, {
  tableName: 'users',
  underscored: true,
  timestamps: true,
});

module.exports = { User };
