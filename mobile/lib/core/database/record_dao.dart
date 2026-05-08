import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// local_database.dart 中的 record DAO 单独拆分
export 'local_database.dart';

// 学习记录查询 DAO 辅助方法（按日期范围）
class RecordDao {
  RecordDao._();
  static final RecordDao instance = RecordDao._();

  /// 获取指定日期段内按科目聚合的时长
  Future<List<Map<String, dynamic>>> getSubjectAgg(
    Database db,
    int userId, {
    String? startDate,
    String? endDate,
  }) async {
    String where = 'user_id = ? AND is_synced != -1';
    final args = <dynamic>[userId];

    if (startDate != null) { where += ' AND started_at >= ?'; args.add(startDate); }
    if (endDate   != null) { where += ' AND started_at < ?';  args.add(endDate); }

    return db.rawQuery(
      '''SELECT subject_name, SUM(duration_sec) as total
         FROM local_records
         WHERE $where
         GROUP BY subject_name
         ORDER BY total DESC''',
      args,
    );
  }

  /// 获取近 N 天每日时长趋势（本地离线）
  Future<List<Map<String, dynamic>>> getDailyTrend(
    Database db,
    int userId,
    int days,
  ) async {
    return db.rawQuery(
      '''SELECT DATE(started_at) as date, SUM(duration_sec) as total
         FROM local_records
         WHERE user_id = ?
           AND started_at >= DATE('now', '-${days - 1} days')
           AND is_synced != -1
         GROUP BY DATE(started_at)
         ORDER BY date ASC''',
      [userId],
    );
  }
}
