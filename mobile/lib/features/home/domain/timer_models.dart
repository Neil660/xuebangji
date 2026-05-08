// 计时器状态模型
enum TimerStatus { idle, running, paused }

class TimerState {
  const TimerState({
    this.status = TimerStatus.idle,
    this.elapsed = Duration.zero,
    this.subjectId,
    this.subjectName,
    this.startedAt,
    this.pausedAt,
    this.totalPausedMs = 0,
    this.switchCount = 0,
  });

  final TimerStatus status;
  final Duration elapsed;
  final int? subjectId;
  final String? subjectName;
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final int totalPausedMs;
  final int switchCount; // 切屏次数（防作弊）

  bool get isRunning => status == TimerStatus.running;
  bool get isPaused  => status == TimerStatus.paused;
  bool get isIdle    => status == TimerStatus.idle;

  String get displayTime {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
           '${m.toString().padLeft(2, '0')}:'
           '${s.toString().padLeft(2, '0')}';
  }

  TimerState copyWith({
    TimerStatus? status,
    Duration? elapsed,
    int? subjectId,
    String? subjectName,
    DateTime? startedAt,
    DateTime? pausedAt,
    int? totalPausedMs,
    int? switchCount,
  }) {
    return TimerState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      totalPausedMs: totalPausedMs ?? this.totalPausedMs,
      switchCount: switchCount ?? this.switchCount,
    );
  }
}

// 学习完成结果
class StudyResult {
  const StudyResult({
    required this.durationSeconds,
    required this.startedAt,
    required this.endedAt,
    this.subjectId,
    this.subjectName,
    this.note,
  });

  final int durationSeconds;
  final DateTime startedAt;
  final DateTime endedAt;
  final int? subjectId;
  final String? subjectName;
  final String? note;
}
