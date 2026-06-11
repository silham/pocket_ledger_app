import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// Scaffold with the bottom navigation bar and the prominent center
/// Add button. Hosts the four tab branches (Home, Transactions, People, More).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.add),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              index: 0,
              shell: navigationShell,
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long,
              label: 'History',
              index: 1,
              shell: navigationShell,
            ),
            const Spacer(), // space for the docked FAB
            _NavItem(
              icon: Icons.group_outlined,
              selectedIcon: Icons.group,
              label: 'People',
              index: 2,
              shell: navigationShell,
            ),
            _NavItem(
              icon: Icons.menu_outlined,
              selectedIcon: Icons.menu,
              label: 'More',
              index: 3,
              shell: navigationShell,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.shell,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final selected = shell.currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    final color =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
