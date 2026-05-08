import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _showAds;
  late int _antiSwitchSec;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).valueOrNull;
    _showAds = user?.showAds ?? true;
    _antiSwitchSec = user?.antiSwitchSec ?? 30;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // ── 主题设置 ─────────────────────────────────────
          _Section(title: '显示', children: [
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('主题'),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox.shrink(),
                onChanged: (v) {
                  if (v != null) ref.read(themeModeProvider.notifier).set(v);
                },
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                ],
              ),
            ),
          ]),

          // ── 广告设置 ─────────────────────────────────────
          _Section(title: '广告', children: [
            SwitchListTile(
              secondary: const Icon(Icons.ad_units_outlined),
              title: const Text('显示排行榜广告'),
              subtitle: const Text('关闭后广告栏目将隐藏'),
              value: _showAds,
              onChanged: (v) async {
                setState(() => _showAds = v);
                await ref.read(profileRepoProvider).updateProfile({'showAds': v});
              },
            ),
          ]),

          // ── 防作弊设置 ────────────────────────────────────
          _Section(title: '学习设置', children: [
            ListTile(
              leading: const Icon(Icons.screen_lock_portrait_outlined),
              title: const Text('防切屏超时时间'),
              subtitle: Text('切屏超过 $_antiSwitchSec 秒自动暂停'),
              trailing: DropdownButton<int>(
                value: _antiSwitchSec,
                underline: const SizedBox.shrink(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _antiSwitchSec = v);
                  await ref.read(profileRepoProvider)
                      .updateProfile({'antiSwitchSec': v});
                },
                items: const [
                  DropdownMenuItem(value: 15,  child: Text('15秒')),
                  DropdownMenuItem(value: 30,  child: Text('30秒')),
                  DropdownMenuItem(value: 60,  child: Text('60秒')),
                  DropdownMenuItem(value: 120, child: Text('2分钟')),
                  DropdownMenuItem(value: 300, child: Text('5分钟（宽松）')),
                ],
              ),
            ),
          ]),

          // ── 学习目标 ─────────────────────────────────────
          _Section(title: '学习目标', children: [
            _GoalTile(
              label: '每日目标',
              icon: Icons.today,
              goalKey: 'dailyGoalSec',
            ),
            const Divider(indent: 56, height: 1),
            _GoalTile(
              label: '每周目标',
              icon: Icons.date_range,
              goalKey: 'weeklyGoalSec',
            ),
            const Divider(indent: 56, height: 1),
            _GoalTile(
              label: '每月目标',
              icon: Icons.calendar_month,
              goalKey: 'monthlyGoalSec',
            ),
          ]),

          // ── 通知设置 ─────────────────────────────────────
          _Section(title: '通知', children: [
            _NotificationToggle(prefKey: 'notify_study', label: '学习提醒'),
            const Divider(indent: 56, height: 1),
            _NotificationToggle(prefKey: 'notify_rank', label: '排名变化提醒'),
            const Divider(indent: 56, height: 1),
            _NotificationToggle(prefKey: 'notify_goal', label: '目标达成提醒'),
          ]),
        ],
      ),
    );
  }
}

// ── 分组标题 ─────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── 目标设置 tile ─────────────────────────────────────────────

class _GoalTile extends ConsumerWidget {
  const _GoalTile({required this.label, required this.icon, required this.goalKey});

  final String label;
  final IconData icon;
  final String goalKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final currentSec = goalKey == 'dailyGoalSec'
        ? (user?.dailyGoalSec ?? 0)
        : goalKey == 'weeklyGoalSec'
            ? (user?.weeklyGoalSec ?? 0)
            : (user?.monthlyGoalSec ?? 0);

    final h = currentSec ~/ 3600;
    final m = (currentSec % 3600) ~/ 60;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(currentSec == 0 ? '未设置' : '${h}小时${m}分钟'),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => _showGoalPicker(context, ref, h, m),
    );
  }

  void _showGoalPicker(BuildContext context, WidgetRef ref, int initH, int initM) {
    int h = initH, m = initM;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('设置$label'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NumberPicker(
                value: h,
                min: 0, max: 24,
                label: '小时',
                onChanged: (v) => setState(() => h = v),
              ),
              const SizedBox(width: 8),
              _NumberPicker(
                value: m,
                min: 0, max: 55, step: 5,
                label: '分钟',
                onChanged: (v) => setState(() => m = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () async {
                final sec = h * 3600 + m * 60;
                await ref.read(profileRepoProvider).updateProfile({goalKey: sec});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberPicker extends StatelessWidget {
  const _NumberPicker({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.step = 1,
  });

  final int value;
  final int min, max, step;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: value > min ? () => onChanged(value - step) : null,
            ),
            SizedBox(
              width: 40,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: value < max ? () => onChanged(value + step) : null,
            ),
          ],
        ),
      ],
    );
  }
}

// ── 通知开关 Tile ─────────────────────────────────────────────

class _NotificationToggle extends StatefulWidget {
  const _NotificationToggle({required this.prefKey, required this.label});

  final String prefKey;
  final String label;

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _enabled = prefs.getBool(widget.prefKey) ?? true);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: Text(widget.label),
      value: _enabled,
      onChanged: (v) async {
        setState(() => _enabled = v);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(widget.prefKey, v);
      },
    );
  }
}