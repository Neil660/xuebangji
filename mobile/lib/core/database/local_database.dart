import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite 本地数据库 - 离线优先存储
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'xuebangji.db'),
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Database get db {
    if (_db == null) throw StateError('数据库未初始化');
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_records (
        id          TEXT PRIMARY KEY,
        server_id   INTEGER,
        user_id     INTEGER NOT NULL,
        subject_id  INTEGER,
        subject_name TEXT,
        started_at  TEXT NOT NULL,
        ended_at    TEXT NOT NULL,
        duration_sec INTEGER NOT NULL,
        note        TEXT,
        is_synced   INTEGER DEFAULT 0,
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE local_subjects (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id   INTEGER,
        user_id     INTEGER NOT NULL,
        name        TEXT NOT NULL,
        icon        TEXT DEFAULT 'book',
        is_default  INTEGER DEFAULT 0,
        is_synced   INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        operation   TEXT NOT NULL,
        payload     TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_records_date ON local_records(started_at DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本迁移
  }

  // ── 学习记录 ────────────────────────────────────────────────

  Future<void> insertRecord(Map<String, dynamic> record) async {
    await db.insert('local_records', record,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryRecords({
    required int userId,
    String? startDate,
    String? endDate,
    int? subjectId,
    int limit = 50,
    int offset = 0,
  }) async {
    String where = 'user_id = ?';
    List<Object?> args = [userId];

    if (startDate != null) {
      where += ' AND started_at >= ?';
      args.add(startDate);
    }
    if (endDate != null) {
      where += ' AND started_at < ?';
      args.add(endDate);
    }
    if (subjectId != null) {
      where += ' AND subject_id = ?';
      args.add(subjectId);
    }

    return db.query('local_records',
        where: where,
        whereArgs: args,
        orderBy: 'started_at DESC',
        limit: limit,
        offset: offset);
  }

  Future<int> getTotalDuration(int userId, {String? startDate, String? endDate}) async {
    String where = 'user_id = ? AND is_synced != -1'; // -1 = 作弊
    List<Object?> args = [userId];

    if (startDate != null) { where += ' AND started_at >= ?'; args.add(startDate); }
    if (endDate != null)   { where += ' AND started_at < ?';  args.add(endDate); }

    final result = await db.rawQuery(
      'SELECT SUM(duration_sec) as total FROM local_records WHERE $where',
      args,
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(int userId) async {
    return db.query('local_records',
        where: 'user_id = ? AND is_synced = 0',
        whereArgs: [userId]);
  }

  Future<void> markRecordSynced(String localId, int serverId) async {
    await db.update('local_records',
        {'is_synced': 1, 'server_id': serverId},
        where: 'id = ?',
        whereArgs: [localId]);
  }

  // ── 科目 ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSubjects(int userId) async {
    return db.query('local_subjects',
        where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<int> upsertSubject(Map<String, dynamic> subject) async {
    return db.insert('local_subjects', subject,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSubject(int serverId) async {
    await db.delete('local_subjects',
        where: 'server_id = ?', whereArgs: [serverId]);
  }

  // ── 同步队列 ────────────────────────────────────────────────

  Future<void> enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  }) async {
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems({int limit = 20}) async {
    return db.query('sync_queue',
        where: 'retry_count < 3',
        orderBy: 'created_at ASC',
        limit: limit);
  }

  Future<void> removeSyncItem(int id) async {
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(int id) async {
    await db.rawUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }
}
