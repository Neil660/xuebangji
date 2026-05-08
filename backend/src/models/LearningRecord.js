const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const LearningRecord = sequelize.define('LearningRecord', {
  id:               { type: DataTypes.BIGINT, primaryKey: true, autoIncrement: true },
  user_id:          { type: DataTypes.BIGINT, allowNull: false },
  subject_id:       { type: DataTypes.BIGINT },
  subject_name:     { type: DataTypes.STRING(50) },
  started_at:       { type: DataTypes.DATE, allowNull: false },
  ended_at:         { type: DataTypes.DATE, allowNull: false },
  duration_seconds: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 0, max: 86400 },
  },
  note:             { type: DataTypes.TEXT },
  is_synced:        { type: DataTypes.BOOLEAN, defaultValue: true },
  cheat_flag:       { type: DataTypes.BOOLEAN, defaultValue: false },
  cheat_reason:     { type: DataTypes.TEXT },
}, {
  tableName: 'learning_records',
  underscored: true,
  timestamps: true,
  updatedAt: false,
});

module.exports = { LearningRecord };
