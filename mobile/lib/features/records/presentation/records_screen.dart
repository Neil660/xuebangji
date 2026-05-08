import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/records_repository.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  String _filter = 'today';
  int _trendDays = 7;

  DateTimeRange? _customRange;

  String? get _startDate {
    final now = DateTime.now();
    switch (_filter) {
      case 'today':
        return DateFormat('yyyy-MM-dd').format(now);
      case 'yesterday':
        return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      case '7days':
        return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
      case '30days':
        return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 29)));
      case 'custom':
        return _customRange != null
            ? DateFormat('yyyy-MM-dd').format(_customRange!.start)
            : null;
      default:
        return null;
    }
  }

  String? get _endDate {
    final now = DateTime.now();
    switch (_filter) {
      case 'yesterday':
        return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      case 'custom':
        return _customRange != null
            ? DateFormat('yyyy-MM-dd').format(_customRange!.end)
            : null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(
      _recordsQueryProvider((_startDate, _endDate)),
    );
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search),
            tooltip: '科目管理',
            onPressed: () => context.push('/subjects'),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '导出',
            onPressed: _exportRecords,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statsProvider);
          ref.invalidate(_recordsQueryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 日期筛选 tabs ────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('today', '今日'),
                  _filterChip('yesterday', '昨日'),
                  _filterChip('7days', '近7天'),
                  _filterChip('30days', '近30天'),
                  _filterChip('custom', '自定义'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 统计汇总 ─────────────────────────────────────
            statsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => _StatsCard(stats: stats),
            ),
            const SizedBox(height: 16),

            // ── 趋势折线图 ───────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('学习趋势',
                            style: Theme.of(context).textTheme.titleMedium),
                        Row(children: [
                          _trendBtn(7, '7天'),
                          const SizedBox(width: 8),
                          _trendBtn(30, '30天'),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: _TrendChart(days: _trendDays),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 记录列表 ─────────────────────────────────────
            Text('学习明细', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (records) {
                if (records.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('暂无记录', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Column(
                  children: records.map((r) => _RecordItem(record: r)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (sel) async {
          if (!sel) return;
          if (value == 'custom') {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (range != null) setState(() { _customRange = range; _filter = value; });
          } else {
            setState(() => _filter = value);
          }
        },
      ),
    );
  }

  Widget _trendBtn(int days, String label) {
    return GestureDetector(
      onTap: () => setState(() => _trendDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _trendDays == days
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
              color: _trendDays == days ? Colors.white : Colors.grey,
              fontSize: 12,
            )),
      ),
    );
  }

  Future<void> _exportRecords() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能：将学习记录保存为 Excel 文件...')),
    );
    // TODO: 实现 Excel 导出逻辑
  }
}

// ── 统计卡片 ─────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final StatsModel stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _StatItem('今日', stats.todaySec),
                _StatItem('本周', stats.weekSec),
                _StatItem('本月', stats.monthSec),
                _StatItem('累计', stats.totalSec),
              ].expand((w) => [Expanded(child: w)]).toList(),
            ),
            if (stats.subjectStats.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('科目分布', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _SubjectPieChart(stats: stats.subjectStats),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(this.label, this.sec);

  final String label;
  final int sec;

  @override
  Widget build(BuildContext context) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    return Column(
      children: [
        Text(h > 0 ? '${h}h${m}m' : '${m}m',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            )),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// ── 科目饼图 ─────────────────────────────────────────────────

class _SubjectPieChart extends StatelessWidget {
  const _SubjectPieChart({required this.stats});

  final List<SubjectStat> stats;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF1976D2), const Color(0xFF43A047),
      const Color(0xFFE53935), const Color(0xFFFB8C00),
      const Color(0xFF8E24AA), const Color(0xFF00ACC1),
    ];
    final total = stats.fold(0, (s, e) => s + e.totalSec);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: List.generate(stats.length, (i) {
                final pct = stats[i].totalSec / total;
                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: stats[i].totalSec.toDouble(),
                  title: '${(pct * 100).toStringAsFixed(0)}%',
                  radius: 60,
                  titleStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(stats.length.clamp(0, 5), (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(stats[i].name, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── 趋势折线图 ────────────────────────────────────────────────

class _TrendChart extends ConsumerWidget {
  const _TrendChart({required this.days});

  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(trendProvider(days));

    return trendAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('加载失败')),
      data: (trend) {
        if (trend.isEmpty) return const Center(child: Text('暂无数据'));

        final spots = trend.asMap().entries.map((e) {
          final sec = (e.value['totalSec'] as int?) ?? 0;
          return FlSpot(e.key.toDouble(), sec / 3600.0);
        }).toList();

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                    final date = trend[idx]['date'] as String? ?? '';
                    final parts = date.split('-');
                    final label = parts.length == 3 ? '${parts[1]}/${parts[2]}' : '';
                    if (days == 7 || idx % 5 == 0) {
                      return Text(label, style: const TextStyle(fontSize: 10));
                    }
                    return const SizedBox.shrink();
                  },
                  reservedSize: 22,
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 2,
                dotData: FlDotData(
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 3,
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 记录列表项 ────────────────────────────────────────────────

class _RecordItem extends StatelessWidget {
  const _RecordItem({required this.record});

  final RecordModel record;

  @override
  Widget build(BuildContext context) {
    final startFmt = DateFormat('HH:mm').format(record.startedAt);
    final endFmt   = DateFormat('HH:mm').format(record.endedAt);
    final dateFmt  = DateFormat('M月d日').format(record.startedAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          child: Text(record.subjectName?.substring(0, 1) ?? '学',
              style: TextStyle(color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(record.subjectName ?? '自由学习',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateFmt  $startFmt — $endFmt',
                style: const TextStyle(fontSize: 12)),
            if (record.note != null && record.note!.isNotEmpty)
              Text(record.note!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(record.displayDuration,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                )),
            Icon(
              record.isSynced ? Icons.cloud_done : Icons.cloud_off,
              size: 14,
              color: record.isSynced ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

// ── FamilyProvider for record queries ────────────────────────

final _recordsQueryProvider = FutureProvider.family<List<RecordModel>, (String?, String?)>(
  (ref, params) {
    return ref.read(recordsRepositoryProvider).getRecords(
      startDate: params.$1,
      endDate: params.$2,
    );
  },
);
