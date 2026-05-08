// API 端点常量
class ApiEndpoints {
  ApiEndpoints._();

  // 认证
  static const String tracks        = '/auth/tracks';
  static const String sendSms       = '/auth/sms';
  static const String register      = '/auth/register';
  static const String login         = '/auth/login';
  static const String loginSms      = '/auth/login-sms';
  static const String resetPassword = '/auth/reset-password';
  static const String refreshToken  = '/auth/refresh';
  static const String updateFcm     = '/auth/fcm-token';

  // 用户
  static const String me            = '/users/me';
  static const String updateProfile = '/users/me';
  static const String changePassword= '/users/me/password';
  static const String loginLogs     = '/users/me/login-logs';
  static const String uploadAvatar  = '/users/me/avatar';

  // 科目
  static const String subjects      = '/subjects';
  static String subject(int id)  => '/subjects/$id';

  // 学习记录
  static const String records       = '/records';
  static String record(int id)   => '/records/$id';
  static const String recordsStats  = '/records/stats';
  static const String recordsTrend  = '/records/trend';
  static const String recordsExport = '/records/export';

  // 排行榜
  static const String leaderboard   = '/leaderboard';
  static const String myRank        = '/leaderboard/my-rank';

  // 通知
  static const String notifications       = '/notifications';
  static String notification(int id)   => '/notifications/$id';
  static const String readAllNotifications= '/notifications/read-all';

  // 广告
  static const String advertisements  = '/advertisements';
}
