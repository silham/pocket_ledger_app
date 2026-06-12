import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: const [
          _MoreTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Accounts',
            route: AppRoutes.moreAccounts,
          ),
          _MoreTile(
            icon: Icons.category_outlined,
            title: 'Categories',
            route: AppRoutes.moreCategories,
          ),
          _MoreTile(
            icon: Icons.pie_chart_outline,
            title: 'Budgets',
            route: AppRoutes.moreBudgets,
          ),
          _MoreTile(
            icon: Icons.bar_chart_outlined,
            title: 'Reports',
            route: AppRoutes.moreReports,
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            route: AppRoutes.moreSettings,
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
