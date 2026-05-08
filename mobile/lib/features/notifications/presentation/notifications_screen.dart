import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/notification_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息通知'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepoProvider).clearAll();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('清空'),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('暂无消息', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final n = notifications[i];
              return Dismissible(
                key: Key('notif_${n.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await ref.read(notificationRepoProvider).delete(n.id);
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadCountProvider);
                },
                child: ListTile(
                  tileColor: n.isRead ? null : Theme.of(ctx).colorScheme.primary.withOpacity(0.05),
                  leading: _NotifIcon(type: n.type),
                  title: Text(n.title,
                      style: TextStyle(
                          fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(
                        DateFormat('M月d日 HH:mm').format(n.createdAt.toLocal()),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!n.isRead) {
                      await ref.read(notificationRepoProvider).markRead(n.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotifIcon extends StatelessWidget {
  const _NotifIcon({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (type) {
      case 'rank_change':
        icon = Icons.leaderboard; color = Colors.blue; break;
      case 'goal_reached':
        icon = Icons.emoji_events; color = Colors.orange; break;
      case 'goal_remind':
        icon = Icons.timer; color = Colors.green; break;
      case 'study_remind':
        icon = Icons.school; color = Colors.purple; break;
      default:
        icon = Icons.notifications; color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
