import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/timer_service.dart';
import '../domain/timer_models.dart';
import '../../records/data/records_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 防切屏：App 切后台时处理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final timerState = ref.read(timerProvider);
      if (timerState.isRunning) {
        final user = ref.read(authProvider).valueOrNull;
        final antiSec = user?.antiSwitchSec ?? 30;
        ref.read(timerProvider.notifier).handleAppBackground(antiSec);
      }
    }
  }

  Future<void> _startStudy() async {
    // 选择科目弹窗
    final subjects = await ref.read(subjectListProvider.future).catchError((_) => <SubjectModel>[]);
    if (!mounted) return;

    SubjectModel? selected;
    if (subjects.isNotEmpty) {
      selected = await showModalBottomSheet<SubjectModel>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _SubjectPickerSheet(subjects: subjects),
      );
    }

    await ref.read(timerProvider.notifier).start(
      subjectId: selected?.id,
      subjectName: selected?.name,
    );
    HapticFeedback.mediumImpact();
  }

  Future<void> _stopStudy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _StopConfirmDialog(),
    );
    if (confirmed != true) return;

    // 弹出备注输入
    String? note;
    if (mounted) {
      note = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => const _NoteInputSheet(),
      );
    }

    final result = await ref.read(timerProvider.notifier).stop();
    if (result == null || !mounted) return;

    // 保存记录
    final finalResult = StudyResult(
      durationSeconds: result.durationSeconds,
      startedAt: result.startedAt,
      endedAt: result.endedAt,
      subjectId: result.subjectId,
      subjectName: result.subjectName,
      note: note,
    );

    await ref.read(recordsRepositoryProvider).saveRecord(finalResult);
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('学习完成！共记录 ${_formatSec(finalResult.durationSeconds)}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatSec(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}小时${m}分${s}秒';
    if (m > 0) return '${m}分${s}秒';
    return '${s}秒';
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final user  = ref.watch(authProvider).valueOrNull;
    final colors = Theme.of(context).extension<AppColors>()!;
    final today = DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(DateTime.now());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── 顶部栏 ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(today,
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          user != null ? '你好，${user.nickname}' : '你好',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: user?.avatarUrl != null
                          ? ClipOval(child: Image.network(user!.avatarUrl!, fit: BoxFit.cover))
                          : Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── 计时器核心区 ────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colors.timerBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 科目标签
                  if (timer.subjectName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timer.subjectName!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (timer.subjectName != null) const SizedBox(height: 16),

                  // 时间显示
                  Text(
                    timer.displayTime,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 4,
                      color: Theme.of(context).colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    timer.isRunning
                        ? '专注学习中...'
                        : timer.isPaused
                            ? '已暂停'
                            : '点击开始，开启学习',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── 操作按钮区 ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildControls(timer),
            ),

            const Spacer(),

            // ── 今日进度条 ──────────────────────────────────
            if (user != null && user.dailyGoalSec > 0)
              _TodayGoalBar(user: user),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(TimerState timer) {
    if (timer.isIdle) {
      return ElevatedButton.icon(
        onPressed: _startStudy,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('开始学习'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: timer.isRunning
                ? () => ref.read(timerProvider.notifier).pause()
                : () => ref.read(timerProvider.notifier).resume(),
            icon: Icon(timer.isRunning ? Icons.pause : Icons.play_arrow),
            label: Text(timer.isRunning ? '暂停' : '继续'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _stopStudy,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('结束学习'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 今日目标进度条 ──────────────────────────────────────────

class _TodayGoalBar extends ConsumerWidget {
  const _TodayGoalBar({required this.user});

  final user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(todayStatsProvider);

    return statsAsync.maybeWhen(
      data: (todaySec) {
        final goal = user.dailyGoalSec as int;
        final progress = (todaySec / goal).clamp(0.0, 1.0);
        final remaining = (goal - todaySec).clamp(0, goal);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('今日目标', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remaining > 0
                        ? '距离目标还有 ${_fmtSec(remaining)}'
                        : '今日目标已完成！',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  String _fmtSec(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}小时${m}分钟';
    return '${m}分钟';
  }
}

// ── 科目选择 Sheet ──────────────────────────────────────────

class _SubjectPickerSheet extends StatelessWidget {
  const _SubjectPickerSheet({required this.subjects});

  final List<SubjectModel> subjects;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择学习科目', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...subjects.map((s) => ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(s.name),
            trailing: s.isDefault ? const Icon(Icons.star, color: Colors.amber, size: 18) : null,
            onTap: () => Navigator.pop(context, s),
          )),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.grey),
            title: const Text('不选择科目', style: TextStyle(color: Colors.grey)),
            onTap: () => Navigator.pop(context, null),
          ),
        ],
      ),
    );
  }
}

// ── 结束确认弹窗 ────────────────────────────────────────────

class _StopConfirmDialog extends StatelessWidget {
  const _StopConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('结束学习'),
      content: const Text('确定要结束本次学习并保存记录吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('继续学习'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认结束'),
        ),
      ],
    );
  }
}

// ── 备注输入 Sheet ──────────────────────────────────────────

class _NoteInputSheet extends StatefulWidget {
  const _NoteInputSheet();

  @override
  State<_NoteInputSheet> createState() => _NoteInputSheetState();
}

class _NoteInputSheetState extends State<_NoteInputSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('添加学习备注（可选）',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: '如：复习了Java基础...',
              border: OutlineInputBorder(),
            ),
            maxLength: 200,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('跳过'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
