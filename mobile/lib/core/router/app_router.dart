import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/records/presentation/records_screen.dart';
import '../../features/records/presentation/subject_manage_screen.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isLoggedIn = ref.read(isLoggedInProvider);
      final loc = state.matchedLocation;

      if (isLoading) return null;

      final publicRoutes = ['/splash', '/login', '/register'];
      if (!isLoggedIn && !publicRoutes.contains(loc)) return '/login';
      if (isLoggedIn && (loc == '/login' || loc == '/register')) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (ctx, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, _) => const RegisterScreen()),

      // 主框架（底部 Tab）
      ShellRoute(
        builder: (ctx, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/',       builder: (ctx, _) => const HomeScreen()),
          GoRoute(path: '/records',builder: (ctx, _) => const RecordsScreen()),
          GoRoute(path: '/leaderboard', builder: (ctx, _) => const LeaderboardScreen()),
          GoRoute(path: '/profile', builder: (ctx, _) => const ProfileScreen()),
        ],
      ),

      // 二级页面
      GoRoute(path: '/subjects',     builder: (ctx, _) => const SubjectManageScreen()),
      GoRoute(path: '/settings',     builder: (ctx, _) => const SettingsScreen()),
      GoRoute(path: '/notifications',builder: (ctx, _) => const NotificationsScreen()),
    ],
  );
});
