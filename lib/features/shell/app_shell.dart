import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Dashboard', short: 'Home'),
    (icon: Icons.chat_bubble_outline, selected: Icons.chat_bubble, label: 'Chat', short: 'Chat'),
    (icon: Icons.calculate_outlined, selected: Icons.calculate, label: 'Calculator', short: 'Calc'),
    (icon: Icons.history, selected: Icons.history, label: 'History', short: 'History'),
    (icon: Icons.hub_outlined, selected: Icons.hub, label: 'Integration', short: 'Connect'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings', short: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        centerTitle: false,
      ),
      body: Row(
        children: [
          if (isWide) ...[
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: navigationShell.goBranch,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.short,
                  ),
              ],
            ),
    );
  }
}
