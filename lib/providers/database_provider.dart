import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';

/// Single app-wide database instance. Repositories depend on this;
/// tests override it with AppDatabase.forTesting(NativeDatabase.memory()).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
