import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../database/local_database.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';

/// 离线同步管理器
/// 职责：监听网络恢复 → 上传本地未同步数据 → 最多重试3次
class SyncManager {
  SyncManager(this._ref) {
    _listen();
  }

  final Ref _ref;
  StreamSubscription? _sub;
  bool _syncing = false;

  void _listen() {
    _sub = _ref.listen(connectivityProvider, (prev, next) {
      next.whenData((isOnline) {
        if (isOnline && !_syncing) {
          _syncAll();
        }
      });
    }) as StreamSubscription?;
  }

  Future<void> _syncAll() async {
    _syncing = true;
    try {
      await _syncRecords();
      await _processSyncQueue();
    } finally {
      _syncing = false;
    }
  }

  /// 同步未上传的学习记录
  Future<void> _syncRecords() async {
    final userId = _ref.read(authProvider).valueOrNull?.id;
    if (userId == null) return;

    final unsynced = await LocalDatabase.instance.getUnsyncedRecords(userId);
    if (unsynced.isEmpty) return;

    final api = _ref.read(apiClientProvider);

    for (final row in unsynced) {
      try {
        final resp = await api.post(ApiEndpoints.records, data: {
          'startedAt':       row['started_at'],
          'endedAt':         row['ended_at'],
          'durationSeconds': row['duration_sec'],
          'subjectId':       row['subject_id'],
          'note':            row['note'],
        });
        final serverId = int.parse(resp['data']['id'].toString());
        await LocalDatabase.instance.markRecordSynced(
            row['id'] as String, serverId);
      } catch (_) {
        // 失败跳过，等下次同步
      }
    }
  }

  /// 处理同步队列（其他类型的操作）
  Future<void> _processSyncQueue() async {
    final pending = await LocalDatabase.instance.getPendingSyncItems();
    final api = _ref.read(apiClientProvider);

    for (final item in pending) {
      final id        = item['id'] as int;
      final type      = item['entity_type'] as String;
      final operation = item['operation'] as String;
      final payload   = jsonDecode(item['payload'] as String) as Map<String, dynamic>;

      try {
        switch ('$type.$operation') {
          case 'record.create':
            await api.post(ApiEndpoints.records, data: payload);
            break;
          case 'subject.create':
            await api.post(ApiEndpoints.subjects, data: payload);
            break;
          default:
            break;
        }
        await LocalDatabase.instance.removeSyncItem(id);
      } catch (_) {
        await LocalDatabase.instance.incrementRetry(id);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}

// Provider
final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});
