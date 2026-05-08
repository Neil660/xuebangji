const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Subject = sequelize.define('Subject', {
  id:         { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  user_id:    { type: DataTypes.BIGINT, allowNull: false },
  name:       { type: DataTypes.STRING(50), allowNull: false },
  icon:       { type: DataTypes.STRING(100), defaultValue: 'book' },
  is_default: { type: DataTypes.BOOLEAN, defaultValue: false },
}, {
  tableName: 'subjects',
  underscored: true,
  timestamps: true,
  updatedAt: false,
  indexes: [{ unique: true, fields: ['user_id', 'name'] }],
});

module.exports = { Subject };
