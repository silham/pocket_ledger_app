import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';

/// Stable icon keys stored in the DB (categories/accounts) mapped to
/// Material icons. Keys are part of the data model — add freely, never rename.
const categoryIcons = <String, IconData>{
  'food': Icons.restaurant_outlined,
  'transport': Icons.directions_bus_outlined,
  'education': Icons.school_outlined,
  'subscriptions': Icons.subscriptions_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'health': Icons.favorite_outline,
  'entertainment': Icons.movie_outlined,
  'family': Icons.family_restroom_outlined,
  'bills': Icons.receipt_outlined,
  'mobile': Icons.smartphone_outlined,
  'travel': Icons.flight_outlined,
  'university': Icons.account_balance_outlined,
  'business': Icons.work_outline,
  'salary': Icons.payments_outlined,
  'freelance': Icons.laptop_outlined,
  'gift': Icons.card_giftcard_outlined,
  'refund': Icons.replay_outlined,
  'cash': Icons.money_outlined,
  'other': Icons.label_outline,
};

IconData categoryIcon(String? key) =>
    categoryIcons[key] ?? Icons.label_outline;

IconData accountTypeIcon(AccountType type) => switch (type) {
      AccountType.cash => Icons.money_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.wallet => Icons.account_balance_wallet_outlined,
      AccountType.savings => Icons.savings_outlined,
      AccountType.creditCard => Icons.credit_card_outlined,
      AccountType.other => Icons.wallet_outlined,
    };

String accountTypeLabel(AccountType type) => switch (type) {
      AccountType.cash => 'Cash',
      AccountType.bank => 'Bank',
      AccountType.wallet => 'Wallet',
      AccountType.savings => 'Savings',
      AccountType.creditCard => 'Credit card',
      AccountType.other => 'Other',
    };

/// Palette offered by the color pickers (same family as the PWA's
/// category colors).
const pickerColors = <String>[
  '#f97316', '#f59e0b', '#84cc16', '#22c55e', '#10b981', '#14b8a6',
  '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1', '#8b5cf6', '#a855f7',
  '#ec4899', '#ef4444', '#64748b', '#9ca3af',
];
