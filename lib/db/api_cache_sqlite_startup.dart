import 'api_cache_response_database.dart';
import 'package:sqflite/sqflite.dart';

import '../api_cache_delegate.dart';
import 'api_cache_database.dart';
import 'api_cache_relationship_database.dart';
import 'create_tables.dart';

mixin ApiCacheSqliteStartupMixin {
  Future<Database> openApiCacheDatabase({required String id}) async {
    await ApiCacheDatabase.close();
    final path = '${await getDatabasesPath()}/cache_x_$id.db';
    final database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) =>
          ApiCacheResponseTableCreator().createApiResponseCacheTable(db),
      onOpen: _onOpen,
    );
    ApiCacheDatabase.attach(database);
    return database;
  }

  Future<void> _onOpen(Database database) async {
    final clearBefore = ApiCacheDelegate.clearBefore();
    if (clearBefore != null) {
      await database.rawDelete(
        'DELETE FROM api_response_cache WHERE create_date < ?',
        [clearBefore.millisecondsSinceEpoch],
      );
    }
    await ApiCacheResponseTableCreator().prepareCacheStateForToday(database);
    await ApiCacheRelationshipDatabase(database: database)
        .replaceAll(ApiCacheDelegate.relationships());
    ApiCacheResponseDatabase(database: database).logApiCacheStats();
  }

  Future<void> updateApiCacheRelationshipsDatabase() async {
    try {
      final database = ApiCacheDatabase.database;
      if (database == null) return;
      await ApiCacheRelationshipDatabase(database: database)
          .replaceAll(ApiCacheDelegate.relationships());
    } catch (e,s) {
      ApiCacheDelegate.logError?.call(e,s);
    }
  }

  Future<void> close() => ApiCacheDatabase.close();
}

class ApiCacheSqliteStartup with ApiCacheSqliteStartupMixin {}
