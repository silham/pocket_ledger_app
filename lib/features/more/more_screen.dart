import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: const [
          _MoreTile(icon: Icons.account_balance_wallet_outlined, title: 'Accounts'),
          _MoreTile(icon: Icons.category_outlined, title: 'Categories'),
          _MoreTile(icon: Icons.pie_chart_outline, title: 'Budgets'),
          _MoreTile(icon: Icons.bar_chart_outlined, title: 'Reports'),
          _MoreTile(icon: Icons.settings_outlined, title: 'Settings'),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title — coming in Phase 8')),
      ),
    );
  }
}
