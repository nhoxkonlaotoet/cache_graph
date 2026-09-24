import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../api_cache_delegate.dart';
import '../api_cache_session.dart';
import '../db/api_cache_response_database.dart';
import '../db/api_cache_relationship_database.dart';
import 'api_cache_hit_refresh_manager.dart';
import '../model/api_cache_config.dart';
import 'package:flutter/foundation.dart';

part 'base_cache_interceptor_mixin.dart';
part 'read_cache_interceptor_mixin.dart';
part 'write_cache_interceptor_mixin.dart';

const _cacheHitExtraKey = 'api_response_cache_hit';


/// Reads a configured GET response from SQLite before Dio sends it to network.
class ReadCacheInterceptor extends Interceptor
    with BaseCacheInterceptorMixin, ReadCacheInterceptorMixin {
  final _cacheDatabase = ApiCacheResponseDatabase();
  final ApiCacheHitRefreshManager _hitRefreshManager;

  ReadCacheInterceptor({ApiCacheHitRefreshManager? hitRefreshManager})
      : _hitRefreshManager = hitRefreshManager ?? ApiCacheHitRefreshManager();

  @override
  ApiCacheResponseDatabase get cacheDatabase => _cacheDatabase;

  @override
  bool get isApiCacheEnabled => ApiCacheDelegate.isEnabled();

  @override
  ApiCacheHitRefreshManager get hitRefreshManager => _hitRefreshManager;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (isApiCacheEnabled) {
      final response = await getCachedResponse(options);
      if (response != null) {
        handler.resolve(response);
        return;
      }
    }
    handler.next(options);
  }

}

class WriteCacheInterceptor extends Interceptor
    with BaseCacheInterceptorMixin, WriteCacheInterceptorMixin {
  final _cacheDatabase = ApiCacheResponseDatabase();
  final _relationshipDatabase = ApiCacheRelationshipDatabase();

  @override
  ApiCacheResponseDatabase get cacheDatabase => _cacheDatabase;

  @override
  bool get isApiCacheEnabled => ApiCacheDelegate.isEnabled();

  @override
  ApiCacheRelationshipDatabase get relationshipDatabase => _relationshipDatabase;

  @override
  Future<void> onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) async {
    if (isApiCacheEnabled) {
      await cache(response);
      unawaited(invalidateRelatedCaches(response));
    }
    handler.next(response);
  }
}

/*
  Tach class de NotifyErrorInterceptors nhan duoc tin hieu loi
 */
class StaleCacheInterceptor extends Interceptor
    with BaseCacheInterceptorMixin, ReadCacheInterceptorMixin {
  final _cacheDatabase = ApiCacheResponseDatabase();
  final _hitRefreshManager = ApiCacheHitRefreshManager();

  @override
  ApiCacheResponseDatabase get cacheDatabase => _cacheDatabase;

  @override
  bool get isApiCacheEnabled => ApiCacheDelegate.isEnabled();

  @override
  ApiCacheHitRefreshManager get hitRefreshManager => _hitRefreshManager;

  @override
  Future<void> onError(
      DioException err,
      ErrorInterceptorHandler handler,
      ) async {
    final options = err.requestOptions;
    final isTemporaryServerFailure =
        err.response?.statusCode == 502 || err.response?.statusCode == 503;
    if (!isApiCacheEnabled ||
        (err.type != DioExceptionType.connectionError &&
            !isTemporaryServerFailure) ||
        cacheConfigFor(options) == null) {
      handler.next(err);
      return;
    }
    debugPrint('[ApiCache] API error, find stale cache ${options.path}');
    final response = await getCachedResponse(options, staleFallback: true, trackHit: false);

    if (response == null) {
      handler.next(err);
      return;
    }
    handler.resolve(response);
  }
}
