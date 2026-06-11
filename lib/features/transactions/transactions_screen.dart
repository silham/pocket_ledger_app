import 'package:flutter/material.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Center(
        child: Text(
          'Transaction history (Phase 5)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
