// 用户模型
class UserModel {
  const UserModel({
    required this.id,
    required this.nickname,
    this.phone,
    this.avatarUrl,
    required this.trackId,
    this.trackName,
    this.dailyGoalSec = 0,
    this.weeklyGoalSec = 0,
    this.monthlyGoalSec = 0,
    this.antiSwitchSec = 30,
    this.showAds = true,
    this.showDetails = true,
    this.showRank = true,
    this.badges = const [],
  });

  final int id;
  final String nickname;
  final String? phone;
  final String? avatarUrl;
  final int trackId;
  final String? trackName;
  final int dailyGoalSec;
  final int weeklyGoalSec;
  final int monthlyGoalSec;
  final int antiSwitchSec;
  final bool showAds;
  final bool showDetails;
  final bool showRank;
  final List<String> badges;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.parse(json['id'].toString()),
      nickname: json['nickname'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      trackId: (json['track_id'] ?? 0) as int,
      trackName: json['track_name'] as String?,
      dailyGoalSec: (json['daily_goal_sec'] ?? 0) as int,
      weeklyGoalSec: (json['weekly_goal_sec'] ?? 0) as int,
      monthlyGoalSec: (json['monthly_goal_sec'] ?? 0) as int,
      antiSwitchSec: (json['anti_switch_sec'] ?? 30) as int,
      showAds: (json['show_ads'] ?? true) as bool,
      showDetails: (json['show_details'] ?? true) as bool,
      showRank: (json['show_rank'] ?? true) as bool,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((b) => b.toString())
              .toList() ??
          [],
    );
  }

  UserModel copyWith({
    String? nickname,
    String? avatarUrl,
    int? trackId,
    String? trackName,
    int? dailyGoalSec,
    int? weeklyGoalSec,
    int? monthlyGoalSec,
    int? antiSwitchSec,
    bool? showAds,
    bool? showDetails,
    bool? showRank,
    List<String>? badges,
  }) {
    return UserModel(
      id: id,
      nickname: nickname ?? this.nickname,
      phone: phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      trackId: trackId ?? this.trackId,
      trackName: trackName ?? this.trackName,
      dailyGoalSec: dailyGoalSec ?? this.dailyGoalSec,
      weeklyGoalSec: weeklyGoalSec ?? this.weeklyGoalSec,
      monthlyGoalSec: monthlyGoalSec ?? this.monthlyGoalSec,
      antiSwitchSec: antiSwitchSec ?? this.antiSwitchSec,
      showAds: showAds ?? this.showAds,
      showDetails: showDetails ?? this.showDetails,
      showRank: showRank ?? this.showRank,
      badges: badges ?? this.badges,
    );
  }
}

// 赛道模型
class TrackModel {
  const TrackModel({
    required this.id,
    required this.category,
    required this.name,
  });

  final int id;
  final String category;
  final String name;

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      id: (json['id'] as int?) ?? 0,
      category: json['category'] as String,
      name: json['name'] as String,
    );
  }
}
