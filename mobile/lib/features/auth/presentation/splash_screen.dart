import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听认证状态，认证完成后自动导航
    ref.listen(authProvider, (prev, next) {
      next.whenData((user) {
        if (user != null) {
          context.go('/');
        } else {
          context.go('/login');
        }
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 56,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '学榜记',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '自律从记录开始',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 60),
            const CircularProgressIndicator(
              color: Colors.white70,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
