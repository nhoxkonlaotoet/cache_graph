import '../model/api_cache_relationship.dart';
import 'package:sqflite/sqflite.dart';

import 'api_cache_database.dart';

class ApiCacheRelationshipDatabase {
  static const _tableName = 'api_cache_relationship';
  final Database? _database;

  ApiCacheRelationshipDatabase({Database? database}) : _database = database;

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
  }) =>
      db.query(table, columns: columns, where: where, whereArgs: whereArgs);

  Future<void> replaceAll(List<ApiCacheRelationship> relationships) async {
    final batch = db.batch()..delete(_tableName);
    for (final relationship in relationships.where((item) => item.isValid)) {
      for (final writePath in relationship.writePaths) {
        for (final stalePath in relationship.stalePaths) {
          batch.insert(
            _tableName,
            {
              'write_path': writePath.path,
              'stale_path': stalePath.path,
              'body_regex': writePath.bodyRegex,
              'refetch': stalePath.refetch ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<ApiCacheRelationshipPath>> queryStalePaths(
    String writePath, {
    required String requestBody,
  }) async {
    final rows = await query(
      _tableName,
      columns: const ['stale_path', 'body_regex', 'refetch'],
      where: 'write_path = ?',
      whereArgs: [writePath],
    );
    final paths = <String, bool>{};
    for (final row in rows) {
      final path = row['stale_path'] as String?;
      final bodyRegex = row['body_regex'] as String? ?? '';
      if (path == null || !_matchesRequestBody(bodyRegex, requestBody))
        continue;
      paths[path] = (paths[path] ?? false) || row['refetch'] == 1;
    }
    return paths.entries
        .map((entry) =>
            ApiCacheRelationshipPath(entry.key, reFetch: entry.value))
        .toList();
  }

  bool _matchesRequestBody(String bodyRegex, String requestBody) {
    if (bodyRegex.isEmpty) return true;
    try {
      return RegExp(bodyRegex).hasMatch(requestBody);
    } catch (_) {
      return false;
    }
  }
}

class ApiCacheRelationshipPath {
  final String path;
  final bool reFetch;

  const ApiCacheRelationshipPath(this.path, {required this.reFetch});
}
