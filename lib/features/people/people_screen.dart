import 'package:flutter/material.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: Center(
        child: Text(
          'Lending & borrowing ledger (Phase 7)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
