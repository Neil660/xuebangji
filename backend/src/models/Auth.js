const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const SmsCode = sequelize.define('SmsCode', {
  id: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  phone: { type: DataTypes.STRING(20), allowNull: false },
  code: { type: DataTypes.STRING(10), allowNull: false },
  purpose: { type: DataTypes.STRING(20), allowNull: false }, // register|login|reset_password
  is_used: { type: DataTypes.BOOLEAN, defaultValue: false },
  expires_at: { type: DataTypes.DATE, allowNull: false },
}, {
  tableName: 'sms_codes',
  underscored: true,
  timestamps: true,
  updatedAt: false,
});

const LoginLog = sequelize.define('LoginLog', {
  id: { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  user_id: { type: DataTypes.BIGINT, allowNull: false },
  device_info: { type: DataTypes.TEXT },
  ip_address: { type: DataTypes.STRING(50) },
  location: { type: DataTypes.STRING(100) },
  logged_at: { type: DataTypes.DATE, defaultValue: DataTypes.NOW },
}, {
  tableName: 'login_logs',
  underscored: true,
  timestamps: false,
});

module.exports = { SmsCode, LoginLog };
