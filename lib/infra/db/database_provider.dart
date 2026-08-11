import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// The one database connection.
///
/// Single by construction: Drift holds one SQLite connection and the pipeline's
/// worker isolates are deliberately kept away from it (KTD-13) — they return
/// bytes and the main isolate does every write.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
