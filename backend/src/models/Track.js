const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Track = sequelize.define('Track', {
  id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
  category: { type: DataTypes.STRING(20), allowNull: false },
  name: { type: DataTypes.STRING(50), allowNull: false, unique: true },
  display_order: { type: DataTypes.INTEGER, defaultValue: 0 },
  is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
}, {
  tableName: 'tracks',
  underscored: true,
  timestamps: false,
});

module.exports = { Track };
