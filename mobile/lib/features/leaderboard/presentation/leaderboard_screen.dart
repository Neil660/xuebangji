import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/leaderboard_repository.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _period = 'day';

  static const _periodLabels = {
    'day':   '日榜',
    'week':  '周榜',
    'month': '月榜',
    'total': '总榜',
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final showAds = user?.showAds ?? true;
    final lbAsync = ref.watch(leaderboardProvider((null, _period)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _PeriodTabBar(
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(leaderboardProvider),
        child: lbAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
          data: (lb) => CustomScrollView(
            slivers: [
              // 个人排名卡
              SliverToBoxAdapter(
                child: _MyRankCard(myRank: lb.myRank, trackName: lb.trackName),
              ),

              // 广告位
              if (showAds && lb.advertisement != null)
                SliverToBoxAdapter(
                  child: _AdBanner(ad: lb.advertisement!),
                ),

              // 前3名
              SliverToBoxAdapter(
                child: _Top3Section(
                  entries: lb.entries.where((e) => e.rank <= 3).toList(),
                  myUserId: user?.id ?? 0,
                ),
              ),

              // 排行榜列表（4名+）
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final entry = lb.entries.where((e) => e.rank > 3).toList()[i];
                    return _RankListItem(
                      entry: entry,
                      isMe: entry.userId == (user?.id ?? 0),
                      onTap: () => _showUserDetail(context, entry),
                    );
                  },
                  childCount: lb.entries.where((e) => e.rank > 3).length,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetail(BuildContext context, LeaderboardEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserDetailSheet(
        entry: entry,
        repo: ref.read(leaderboardRepoProvider),
      ),
    );
  }
}

// ── 时间维度 Tab ──────────────────────────────────────────────

class _PeriodTabBar extends StatelessWidget {
  const _PeriodTabBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  static const _periods = ['day', 'week', 'month', 'total'];
  static const _labels  = ['日榜', '周榜', '月榜', '总榜'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_periods.length, (i) {
        final sel = selected == _periods[i];
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(_periods[i]),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: sel ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: sel
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── 个人排名卡 ────────────────────────────────────────────────

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({required this.myRank, required this.trackName});

  final MyRank myRank;
  final String trackName;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withBlue(255),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trackName,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              myRank.rank > 0
                  ? Text('当前排名 第${myRank.rank}名',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.bold))
                  : const Text('暂未上榜',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          const Spacer(),
          if (myRank.aboveDiffSec != null && myRank.aboveDiffSec! > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('距上一名', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  _fmtDiff(myRank.aboveDiffSec!),
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _fmtDiff(int sec) {
    final m = sec ~/ 60;
    if (m < 60) return '还差${m}分钟';
    return '还差${m ~/ 60}小时${m % 60}分钟';
  }
}

// ── 广告横幅 ─────────────────────────────────────────────────

class _AdBanner extends StatelessWidget {
  const _AdBanner({required this.ad});

  final AdModel ad;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          if (ad.materialImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ad.materialImage!,
                width: 56, height: 56, fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('赞助', style: TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text(ad.advertiserName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey))),
                ]),
                const SizedBox(height: 4),
                Text(ad.materialName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 前3名展示 ─────────────────────────────────────────────────

class _Top3Section extends StatelessWidget {
  const _Top3Section({required this.entries, required this.myUserId});

  final List<LeaderboardEntry> entries;
  final int myUserId;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // 排列顺序：2-1-3
    final sorted = [...entries]..sort((a, b) {
      final order = {1: 1, 2: 0, 3: 2};
      return (order[a.rank] ?? 3).compareTo(order[b.rank] ?? 3);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: sorted.map((e) {
          final isMe = e.userId == myUserId;
          final height = e.rank == 1 ? 110.0 : e.rank == 2 ? 90.0 : 80.0;

          return Expanded(
            child: Column(
              children: [
                if (isMe)
                  const Text('我', style: TextStyle(fontSize: 12, color: Colors.blue)),
                _RankMedal(rank: e.rank),
                const SizedBox(height: 4),
                Text(e.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(e.displayDuration,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13, fontWeight: FontWeight.bold)),
                Container(
                  height: height,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: _podiumColor(e.rank),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Center(
                    child: Text('${e.rank}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _podiumColor(int rank) {
    switch (rank) {
      case 1: return rankGoldColor;
      case 2: return rankSilverColor;
      case 3: return rankBronzeColor;
      default: return Colors.grey;
    }
  }
}

class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = {1: rankGoldColor, 2: rankSilverColor, 3: rankBronzeColor};
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: colors[rank] ?? Colors.grey,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: (colors[rank] ?? Colors.grey).withOpacity(0.4),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(
        rank == 1 ? Icons.emoji_events : Icons.military_tech,
        color: Colors.white, size: 24,
      ),
    );
  }
}

// ── 排名列表项（4名+）────────────────────────────────────────

class _RankListItem extends StatelessWidget {
  const _RankListItem({
    required this.entry,
    required this.isMe,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;

    // 标识颜色
    Color? badgeColor;
    String? badgeText;
    if (rank <= 50)  { badgeColor = const Color(0xFF1976D2); badgeText = '50'; }
    if (rank <= 9)   { badgeColor = null; badgeText = null; }
    if (rank > 50 && rank <= 100) { badgeColor = const Color(0xFF4CAF50); badgeText = '100'; }

    return ListTile(
      tileColor: isMe ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
      onTap: onTap,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: badgeText != null
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: badgeColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(badgeText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10)),
                  )
                : Text('$rank', style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            child: entry.avatarUrl != null
                ? ClipOval(child: CachedNetworkImage(imageUrl: entry.avatarUrl!,
                    fit: BoxFit.cover))
                : Text(entry.nickname.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      title: Row(
        children: [
          Text(entry.nickname, style: TextStyle(
              fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
          if (isMe)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('(我)', style: TextStyle(color: Colors.blue, fontSize: 12)),
            ),
        ],
      ),
      trailing: Text(
        entry.displayDuration,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ── 用户详情弹窗 ──────────────────────────────────────────────

class _UserDetailSheet extends StatefulWidget {
  const _UserDetailSheet({required this.entry, required this.repo});

  final LeaderboardEntry entry;
  final LeaderboardRepository repo;

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repo.getUserDetail(widget.entry.userId);
      if (mounted) setState(() { _detail = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.entry.nickname,
              style: Theme.of(context).textTheme.titleLarge),
          Text('共学习 ${widget.entry.displayDuration}',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          if (_loading)
            const CircularProgressIndicator()
          else if (_detail != null) ...[
            Text('近7天学习明细', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...((_detail!['details'] as List?) ?? []).take(7).map((d) {
              final item = d as Map<String, dynamic>;
              final totalSec = (item['totalSec'] as int?) ?? 0;
              final h = totalSec ~/ 3600;
              final m = (totalSec % 3600) ~/ 60;
              return ListTile(
                dense: true,
                title: Text(item['date'] as String? ?? ''),
                subtitle: Text(item['subjectName'] as String? ?? ''),
                trailing: Text(h > 0 ? '${h}h${m}m' : '${m}m'),
              );
            }),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
