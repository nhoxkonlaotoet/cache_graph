import '../api_cache_delegate.dart';
import '../model/api_cache_config.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'api_cache_database.dart';

class ApiCacheResponseDatabase {
  static const _tableName = 'api_response_cache';
  static const _cacheStatsTableName = 'cache_stats';
  final Database? _database;

  ApiCacheResponseDatabase({Database? database}) : _database = database;

  Database get db {
    final database = _database ?? ApiCacheDatabase.database;
    if (database == null) {
      throw StateError('API cache database has not been opened.');
    }
    return database;
  }

  bool get isAvailable => _database != null || ApiCacheDatabase.isAvailable;

  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    int? limit,
    String? orderBy,
  }) =>
      db.query(
        table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        limit: limit,
        orderBy: orderBy,
      );

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      db.insert(table, values, conflictAlgorithm: conflictAlgorithm);

  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      db.rawUpdate(sql, arguments);

  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      db.rawDelete(sql, arguments);

  Future<String?> getResponseBody({
    required String cacheKey,
    required ApiCacheScope scope,
    bool staleFallback = false,
    Duration? ttl,
    String? appSessionId,
    String? loginSessionId,
    DateTime? afterDate,
  }) {
    return _getResponseBody(
      cacheKey: cacheKey,
      scope: scope,
      staleWhereClause:
          staleFallback ? 'is_stale = 1 AND allow_stale = 1' : 'is_stale = 0',
      ttl: ttl,
      appSessionId: appSessionId,
      loginSessionId: loginSessionId,
      afterDate: afterDate,
    );
  }

  Future<String?> _getResponseBody({
    required String cacheKey,
    required ApiCacheScope scope,
    required String staleWhereClause,
    Duration? ttl,
    String? appSessionId,
    String? loginSessionId,
    DateTime? afterDate,
  }) async {
    if (!isAvailable) return null;
    final whereClause = StringBuffer(
      'api_path = ? AND scope = ? AND is_delete = 0 AND $staleWhereClause',
    );
    final whereArgs = <Object?>[cacheKey, scope.name];
    switch (scope) {
      case ApiCacheScope.time:
        whereClause.write(' AND create_date > ?');
        whereArgs.add(DateTime.now().millisecondsSinceEpoch -
            (ttl ?? Duration.zero).inMilliseconds);
        break;
      case ApiCacheScope.appSession:
        whereClause.write(' AND app_session_id = ?');
        whereArgs.add(appSessionId);
        break;
      case ApiCacheScope.loginSession:
        whereClause.write(' AND login_session_id = ?');
        whereArgs.add(loginSessionId);
        break;
    }
    whereClause.write(' AND (expired_date IS NULL OR expired_date > ?)');
    whereArgs.add(DateTime.now().millisecondsSinceEpoch);
    if (afterDate != null) {
      whereClause.write(" AND create_date > ?");
      whereArgs.add(afterDate.millisecondsSinceEpoch);
    }
    final records = await query(
      _tableName,
      columns: const ['response_body'],
      where: whereClause.toString(),
      whereArgs: whereArgs,
      limit: 1,
    );
    await saveCacheHit(records.isNotEmpty);
    return records.isEmpty ? null : records.first['response_body'] as String?;
  }

  Future<void> saveCacheHit(bool hit) async {
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    //de y dau ,
    final setHitCountState = hit ? ", hit_count = hit_count + 1 " : "";
    try {
      await rawUpdate("""
      UPDATE cache_stats
        SET
          lookup_count = lookup_count + 1
          $setHitCountState
      WHERE date = ?;
      """, [now]);
    } catch (e) {
      debugPrint("saveCacheHit error but it's okay $e");
    }
  }

  Future<void> saveResponse({
    required String cacheKey,
    required String path,
    required String responseBody,
    required ApiCacheScope scope,
    required bool allowStale,
    required String appSessionId,
    String? loginSessionId,
    Duration? ttl,
  }) {
    final now = DateTime.now();
    return insert(
      _tableName,
      {
        'api_path': cacheKey,
        'path': path,
        'response_body': responseBody,
        'create_date': now.millisecondsSinceEpoch,
        'expired_date': ttl == null
            ? null
            : now.add(ttl).millisecondsSinceEpoch,
        'is_stale': 0,
        'is_delete': 0,
        'allow_stale': allowStale ? 1 : 0,
        'scope': scope.name,
        'app_session_id': appSessionId,
        'login_session_id': loginSessionId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> queryCacheKeysForPaths(Iterable<String> paths) async {
    final normalizedPaths = paths
        .map((path) => _normalizePath(path))
        .where((path) => path.isNotEmpty)
        .toSet();
    if (normalizedPaths.isEmpty) return const [];

    final placeholders = List.filled(normalizedPaths.length, '?').join(', ');
    final rows = await query(
      _tableName,
      columns: const ['api_path'],
      where: 'path IN ($placeholders) AND is_delete = 0',
      whereArgs: normalizedPaths.toList(),
    );
    return rows
        .map((row) => row['api_path'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<void> markResponsesStale(Iterable<String> cacheKeys) async {
    final batch = db.batch();
    for (final cacheKey in cacheKeys.toSet()) {
      batch.update(
        _tableName,
        {'is_stale': 1},
        where: 'api_path = ?',
        whereArgs: [cacheKey],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markResponsesDeleted(Iterable<String> cacheKeys) async {
    final batch = db.batch();
    for (final cacheKey in cacheKeys.toSet()) {
      batch.update(
        _tableName,
        {'is_delete': 1},
        where: 'api_path = ? AND is_delete = 0',
        whereArgs: [cacheKey],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> queryPendingCacheStats({
    required DateTime onOrBefore,
  }) {
    return query(
      _cacheStatsTableName,
      columns: const ['date', 'hit_count', 'lookup_count'],
      where: 'date <= ? AND COALESCE(sync_state, 0) = 0',
      whereArgs: [DateFormat('yyyy-MM-dd').format(onOrBefore)],
      orderBy: 'date ASC',
    );
  }

  Future<int> markCacheStatsSynced(DateTime onOrBefore) {
    return rawUpdate(
      'UPDATE $_cacheStatsTableName SET sync_state = 1 WHERE date <= ?',
      [DateFormat('yyyy-MM-dd').format(onOrBefore)],
    );
  }

  Future<int> deleteCacheStatsOlderThan(DateTime date) {
    return rawDelete(
      'DELETE FROM $_cacheStatsTableName WHERE date < ?',
      [DateFormat('yyyy-MM-dd').format(date)],
    );
  }

  Future<void> logApiCacheStats() async {
    final logCacheStats = ApiCacheDelegate.logCacheStats;
    if (logCacheStats == null) {
      return;
    }
    try {
      final cacheDatabase = ApiCacheResponseDatabase();
      final now = DateTime.now();
      final onOrBefore = now.subtract(const Duration(days: 1));
      final stats = await cacheDatabase.queryPendingCacheStats(
        onOrBefore: onOrBefore,
      );
      logCacheStats.call(stats);
      await cacheDatabase.markCacheStatsSynced(onOrBefore);
      await cacheDatabase.deleteCacheStatsOlderThan(
        now.subtract(const Duration(days: 30)),
      );
    } catch (e) {
      debugPrint('sync api_cache_stats failed: $e');
    }
  }

  String _normalizePath(String path) => path.replaceFirst(RegExp(r'^/'), '');
}
