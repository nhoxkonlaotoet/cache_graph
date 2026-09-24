import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'api_cache_delegate.dart';
import 'db/api_cache_sqlite_startup.dart';
import 'engine/interceptors_cache.dart';
import 'model/api_cache_config.dart';
import 'model/api_cache_relationship.dart';
import 'api_cache_session.dart';

class ApiCache {
  static final readCacheInterceptor = ReadCacheInterceptor();
  static final staleCacheInterceptor = StaleCacheInterceptor();
  static final writeCacheInterceptor = WriteCacheInterceptor();

  static void help() {
    debugPrint("------------START API CACHE HELP----------------");
    debugPrint("Below init dio network:");
    debugPrint("""  dio.interceptors.addAll([
      poolInterceptors,
      ApiCache.readCacheInterceptor, //here
      retryInterceptors,
      interceptors,
      notifyErrorInterceptors,
      ApiCache.writeCacheInterceptor, //here
      ApiCache.staleCacheInterceptor, //here
      perfInterceptor,
    ]);""");
    debugPrint("  ApiCache.configure(reFetch: (uri) => dio.getUri(uri));");
    debugPrint("and");
    debugPrint("  Below login success statement:");
    debugPrint("  ApiCache.configure(...);");
    debugPrint("  ApiCache.startLoginSession();");
    debugPrint("  await ApiCache.openDatabase(id: loginStaffId);");
    debugPrint("and");
    debugPrint("Below logout statement:");
    debugPrint("  await ApiCache.closeDatabase();");
    debugPrint("and");
    debugPrint("Below reload relationships config:");
    debugPrint("  await ApiCache.updateApiCacheRelationshipsDatabase();");
    debugPrint("  //relationships react POST/PUT/PATCH/DELETE request then stale related cache");
    debugPrint("------------END API CACHE HELP----------------");
  }

  static void configure({
    bool Function()? isEnabled,
    List<ApiCacheConfig> Function()? configs,
    List<ApiCacheRelationship> Function()? relationships,
    DateTime? Function()? clearBefore,
    Future<void> Function(Uri)? reFetch,
    Future<void> Function(dynamic e, StackTrace stack)? logError,
    Future<void> Function(List<Map<String, Object?>> stats)? logCacheStats,
  }) {
    ApiCacheDelegate.configure(
      isEnabled: isEnabled, configs: configs, relationships: relationships,
      clearBefore: clearBefore, reFetch: reFetch, logError: logError,
      logCacheStats: logCacheStats,
    );
  }

  static Future<Database> openDatabase({required String id}) async {
    return ApiCacheSqliteStartup().openApiCacheDatabase(id: id);
  }

  static Future<void> updateApiCacheRelationshipsDatabase() async {
    return ApiCacheSqliteStartup().updateApiCacheRelationshipsDatabase();
  }

  static void startLoginSession() => ApiCacheSession.startLoginSession();

  static Future<void> closeDatabase() => ApiCacheSqliteStartup().close();
}
