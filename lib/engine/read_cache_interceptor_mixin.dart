part of 'interceptors_cache.dart';

mixin ReadCacheInterceptorMixin on BaseCacheInterceptorMixin {
  ApiCacheHitRefreshManager get hitRefreshManager;

  Future<Response<dynamic>?> getCachedResponse(
    RequestOptions options, {
    bool staleFallback = false,
    bool trackHit = true,
  }) async {
    final config = cacheConfigFor(options);
    if (options.method != 'GET' || config == null || !cacheDatabase.isAvailable) {
      return null;
    }

    final clearDate = ApiCacheDelegate.clearBefore();
    final cacheKey = cacheKeyFor(options);
    final path = cachePathFor(options);
    try {
      final responseBody = await cacheDatabase.getResponseBody(
        cacheKey: cacheKey,
        scope: config.scope,
        staleFallback: staleFallback,
        ttl: config.ttl,
        appSessionId: ApiCacheSession.appSessionId,
        loginSessionId: ApiCacheSession.loginSessionId,
        afterDate: clearDate,
      );
      if (responseBody == null) {
        hitRefreshManager.reset(path: path);
        return null;
      }

      final shouldRefresh = trackHit &&
          hitRefreshManager.shouldRefresh(path: path, requestKey: cacheKey);
      options.extra[_cacheHitExtraKey] = true;
      debugPrint('cache hit: ${options.uri}');
      if (shouldRefresh) {
        debugPrint('[ApiCache] cache hit threshold reached; refresh: $cacheKey');
        unawaited(_staleAndRefetch(cacheKey));
      }
      return Response(
        requestOptions: options,
        data: decodeResponseBody(responseBody),
        statusCode: 200,
        statusMessage: staleFallback ? 'OK (stale cache fallback)' : 'OK (cache)',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _staleAndRefetch(String cacheKey) async {
    try {
      await cacheDatabase.markResponsesStale([cacheKey]);
      silentRefetchAll([cacheKey]);
    } catch (_) {
      // A background refresh must not change the cached response result.
    }
  }

}
