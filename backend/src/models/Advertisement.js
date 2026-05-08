const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Advertisement = sequelize.define('Advertisement', {
  id:              { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  advertiser_name: { type: DataTypes.STRING(100), allowNull: false },
  material_image:  { type: DataTypes.STRING(500) },
  material_name:   { type: DataTypes.STRING(200), allowNull: false },
  period_type:     { type: DataTypes.STRING(10), allowNull: false }, // month|total
  months:          { type: DataTypes.STRING(200) }, // JSON 数组
  is_active:       { type: DataTypes.BOOLEAN, defaultValue: false },
}, {
  tableName: 'advertisements',
  underscored: true,
  timestamps: true,
});

const Notification = sequelize.define('Notification', {
  id:      { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  user_id: { type: DataTypes.BIGINT, allowNull: false },
  type:    { type: DataTypes.STRING(50), allowNull: false },
  title:   { type: DataTypes.STRING(100), allowNull: false },
  content: { type: DataTypes.TEXT, allowNull: false },
  is_read: { type: DataTypes.BOOLEAN, defaultValue: false },
}, {
  tableName: 'notifications',
  underscored: true,
  timestamps: true,
  updatedAt: false,
});

const UserBadge = sequelize.define('UserBadge', {
  id:         { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  user_id:    { type: DataTypes.BIGINT, allowNull: false },
  badge_type: { type: DataTypes.STRING(50), allowNull: false },
  earned_at:  { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'user_badges',
  underscored: true,
  timestamps: false,
  indexes: [{ unique: true, fields: ['user_id', 'badge_type'] }],
});

module.exports = { Advertisement, Notification, UserBadge };
