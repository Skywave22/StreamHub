import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static int _indexFor(String path) {
    if (path == '/home') return 0;
    if (path.startsWith('/search')) return 1;
    if (path.startsWith('/library')) return 2;
    if (path.startsWith('/settings')) return 3;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        final index = _indexFor(path);
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 840;
            if (isWide) {
              return Scaffold(
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: index < 0 ? 0 : index,
                      onDestinationSelected: (i) => _go(context, i),
                      labelType: NavigationRailLabelType.all,
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Icon(Icons.play_circle_fill_rounded, size: 32),
                      ),
                      destinations: const [
                        NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                        NavigationRailDestination(icon: Icon(Icons.search), selectedIcon: Icon(Icons.search), label: Text('Search')),
                        NavigationRailDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: Text('Library')),
                        NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: child),
                  ],
                ),
              );
            }
            return Scaffold(
              body: child,
              bottomNavigationBar: NavigationBar(
                selectedIndex: index < 0 ? 0 : index,
                onDestinationSelected: (i) => _go(context, i),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Search'),
                  NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Library'),
                  NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/search');
      case 2:
        context.go('/library');
      case 3:
        context.go('/settings');
    }
  }
}
