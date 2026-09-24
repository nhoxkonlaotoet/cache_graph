import '../api_cache_delegate.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

class ApiCacheResponseTableCreator {
  Future<void> prepareCacheStateForToday(Database db) async {
    try {
      final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await db.insert(
        'cache_stats',
        {'date': now, 'hit_count': 0, 'lookup_count': 0, 'sync_state': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e, s) {
      ApiCacheDelegate.logError?.call(e, s);
    }
  }

  Future<void> createApiResponseCacheTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS api_response_cache (
          api_path TEXT PRIMARY KEY,
          path TEXT NOT NULL,
          response_body TEXT,
          create_date text,
          expired_date INTEGER,
          is_stale INTEGER NOT NULL DEFAULT 0,
          is_delete INTEGER NOT NULL DEFAULT 0,
          allow_stale INTEGER NOT NULL DEFAULT 0,
          scope TEXT NOT NULL,
          app_session_id TEXT,
          login_session_id TEXT
        );
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_api_response_cache_path
        ON api_response_cache(path);
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_stats (
          date TEXT PRIMARY KEY,
          hit_count INTEGER,
          lookup_count INTEGER,
          sync_state INTEGER
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS api_cache_relationship (
          write_path TEXT NOT NULL,
          stale_path TEXT NOT NULL,
          body_regex TEXT NOT NULL DEFAULT '',
          refetch INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (write_path, stale_path, body_regex)
        );
      ''');
    } catch (e, s) {
      ApiCacheDelegate.logError?.call(e, s);
    }
  }
}
