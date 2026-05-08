import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '首页', path: '/'),
    _TabItem(icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: '记录', path: '/records'),
    _TabItem(icon: Icons.leaderboard_outlined, activeIcon: Icons.leaderboard, label: '排行榜', path: '/leaderboard'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: '我的', path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path) &&
          (_tabs[i].path != '/' || location == '/')) {
        currentIndex = i;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => context.go(_tabs[index].path),
        destinations: _tabs.map((tab) => NavigationDestination(
          icon: Icon(tab.icon),
          selectedIcon: Icon(tab.activeIcon),
          label: tab.label,
        )).toList(),
        height: 64,
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}
