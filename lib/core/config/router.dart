import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/viewer/manga_viewer_screen.dart';
import '../../presentation/screens/recent/recent_chapters_screen.dart';

part 'router.g.dart';

@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _calculateSelectedIndex(state),
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/');
                    break;
                  case 1:
                    context.go('/search');
                    break;
                  case 2:
                    context.go('/recent');
                    break;
                  case 3:
                    context.go('/settings');
                    break;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '홈',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search),
                  label: '검색',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: '최근',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: '설정',
                ),
              ],
            ),
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/recent',
            builder: (context, state) => const RecentChaptersScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/viewer/:titleId/:chapterId',
        builder: (context, state) => MangaViewerScreen(
          chapterId: state.pathParameters['chapterId'] ?? '',
          title: state.pathParameters['titleId'] ?? '',
        ),
      ),
    ],
  );
}

int _calculateSelectedIndex(GoRouterState state) {
  final location = state.uri.path;
  if (location == '/') {
    return 0;
  }
  if (location.startsWith('/search')) {
    return 1;
  }
  if (location.startsWith('/recent')) {
    return 2;
  }
  if (location.startsWith('/settings')) {
    return 3;
  }
  return 0;
}
