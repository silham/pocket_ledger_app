import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/data/export_service.dart';
import 'package:pocket_ledger_app/domain/ledger/ledger_service.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';

void main() {
  test('export contains every table and survives a JSON round-trip',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final cash = await db.select(db.accounts).getSingle();
    await LedgerService(db).createTransaction(TransactionDraft(
      type: TransactionType.expense,
      amountMinor: 450_00,
      date: DateTime.utc(2026, 6, 11),
      accountId: cash.id,
    ));

    final json = await ExportService(db)
        .buildJson(now: DateTime.utc(2026, 6, 11, 12));
    final decoded = jsonDecode(json) as Map<String, dynamic>;

    expect(decoded['app'], 'pocket_ledger');
    expect(decoded['formatVersion'], 1);
    expect(decoded['exportedAt'], '2026-06-11T12:00:00.000Z');
    expect(decoded['accounts'], hasLength(1));
    expect(decoded['categories'], hasLength(20));
    expect(decoded['transactions'], hasLength(1));
    expect(decoded['people'], isEmpty);
    expect(decoded['budgets'], isEmpty);

    final tx = (decoded['transactions'] as List).single as Map;
    expect(tx['amountMinor'], 450_00);
    expect(tx['accountId'], cash.id);
  });
}
