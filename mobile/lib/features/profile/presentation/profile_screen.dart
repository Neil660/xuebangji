import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import '../../records/data/records_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final statsAsync = ref.watch(userStatsProvider);

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userStatsProvider);
          ref.invalidate(authProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 个人信息卡 ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // 头像
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.grey.shade200,
                              child: user.avatarUrl != null
                                  ? ClipOval(child: CachedNetworkImage(
                                      imageUrl: user.avatarUrl!, fit: BoxFit.cover,
                                      width: 72, height: 72))
                                  : Text(user.nickname.substring(0, 1),
                                      style: const TextStyle(fontSize: 28,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(user.nickname,
                                    style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(width: 8),
                                if (user.badges.contains('discipline_master'))
                                  const Tooltip(
                                    message: '自律达人',
                                    child: Icon(Icons.star, color: Colors.amber, size: 18),
                                  ),
                                if (user.badges.contains('persistence_star'))
                                  const Tooltip(
                                    message: '坚持之星',
                                    child: Icon(Icons.emoji_events,
                                        color: Colors.orange, size: 18),
                                  ),
                              ]),
                              const SizedBox(height: 4),
                              Text(user.trackName ?? '未设置赛道',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showEditSheet(context, ref, user),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('编辑'),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // 数据汇总
                    statsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (stats) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatBadge('累计学习', _fmtSec(stats.totalSec)),
                          _StatBadge('学习天数', '${stats.studyDays}天'),
                          _StatBadge('日均时长', _fmtSec(stats.avgDailySec)),
                          _StatBadge('最长连续', '${stats.maxStreakDays}天'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    // 今日目标
                    if (user.dailyGoalSec > 0) ...[
                      const Divider(height: 16),
                      _GoalProgress(user: user),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text('系统设置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // ── 设置入口列表 ───────────────────────────────
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.tune, label: '基础设置',
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.backup_outlined, label: '数据备份与恢复',
                    onTap: () => _showDataOptions(context),
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.lock_outline, label: '隐私设置',
                    onTap: () => _showPrivacySettings(context, ref, user),
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.help_outline, label: '帮助与反馈',
                    onTap: () {},
                  ),
                  const Divider(indent: 56, height: 1),
                  _SettingsTile(
                    icon: Icons.info_outline, label: '关于我们',
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 退出登录
            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('退出登录', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _fmtSec(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h >= 100) return '${h}h';
    if (h > 0) return '${h}h${m}m';
    return '${m}m';
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authRepositoryProvider).logout();
    }
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  void _showDataOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.cloud_upload), title: const Text('备份数据到云端')),
          ListTile(leading: const Icon(Icons.cloud_download), title: const Text('从云端恢复数据')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('清除本地缓存')),
        ],
      ),
    );
  }

  void _showPrivacySettings(BuildContext context, WidgetRef ref, user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('隐私设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('显示学习详情'),
              subtitle: const Text('允许他人查看你的学习科目和时长'),
              value: user.showDetails,
              onChanged: (v) {
                ref.read(profileRepoProvider).updateProfile({'showDetails': v});
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text('在排行榜中显示排名'),
              value: user.showRank,
              onChanged: (v) {
                ref.read(profileRepoProvider).updateProfile({'showRank': v});
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '学榜记',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 学榜记',
    );
  }
}

// ── 小组件 ────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        )),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _GoalProgress extends ConsumerWidget {
  const _GoalProgress({required this.user});

  final user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayStatsProvider);

    return todayAsync.maybeWhen(
      data: (todaySec) {
        final goal = user.dailyGoalSec as int;
        final pct = (todaySec / goal).clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('今日目标', style: TextStyle(fontSize: 13)),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 6),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ── 编辑个人信息 Sheet ────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _nickCtrl = TextEditingController(text: widget.user.nickname);
  bool _loading = false;

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('编辑个人信息', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nickCtrl,
            decoration: const InputDecoration(labelText: '昵称（2-10位）'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final nick = _nickCtrl.text.trim();
    if (nick.length < 2 || nick.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称长度2-10位'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(profileRepoProvider).updateProfile({'nickname': nick});
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// import missing
import '../../../features/auth/data/auth_repository.dart';
