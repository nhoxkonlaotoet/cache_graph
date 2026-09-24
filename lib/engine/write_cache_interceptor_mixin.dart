part of 'interceptors_cache.dart';

mixin WriteCacheInterceptorMixin on BaseCacheInterceptorMixin {
  ApiCacheRelationshipDatabase get relationshipDatabase;

  Future<void> cache(Response<dynamic> response) async {
    final options = response.requestOptions;
    if (options.method != 'GET') return;
    final config = cacheConfigFor(options);
    if (options.extra[_cacheHitExtraKey] == true ||
        config == null ||
        !cacheDatabase.isAvailable) {
      return;
    }

    try {
      await cacheDatabase.saveResponse(
        cacheKey: cacheKeyFor(options),
        path: cachePathFor(options),
        responseBody: jsonEncode(response.data),
        scope: config.scope,
        allowStale: config.allowStale,
        appSessionId: ApiCacheSession.appSessionId,
        loginSessionId: ApiCacheSession.loginSessionId,
        ttl: config.ttl,
      );
    } catch (_) {
      // Cache write is best-effort and must not change the API result.
    }
  }

  Future<void> invalidateRelatedCaches(Response<dynamic> response) async {
    final options = response.requestOptions;
    const writeMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};
    if (!writeMethods.contains(options.method.toUpperCase()) ||
        !cacheDatabase.isAvailable ||
        !relationshipDatabase.isAvailable) {
      return;
    }

    try {
      final staleRelationships = await relationshipDatabase.queryStalePaths(
        normalizePath(options.uri.path),
        requestBody: requestBodyFor(options),
      );
      final stalePaths = staleRelationships.map((item) => item.path).toList();
      if (stalePaths.isEmpty) return;
      debugPrint(
        '[ApiCache] ${options.method.toUpperCase()} ${options.uri.path} '
        'will stale: ${stalePaths.join(', ')}',
      );

      final cacheKeys = await cacheDatabase.queryCacheKeysForPaths(stalePaths);
      if (cacheKeys.isEmpty) return;
      final refetchPaths = staleRelationships
          .where((item) => item.reFetch)
          .map((item) => item.path)
          .toList();
      final refetchCacheKeys = refetchPaths.isEmpty
          ? const <String>[]
          : await cacheDatabase.queryCacheKeysForPaths(refetchPaths);
      debugPrint('[ApiCache] soft-delete invalidated cache entries: ${cacheKeys.join('\n')}');
      await cacheDatabase.markResponsesDeleted(cacheKeys);
      if (refetchCacheKeys.isNotEmpty) {
        debugPrint(
          '[ApiCache] silent refetch entries: ${refetchCacheKeys.join('\n')}',
        );
        silentRefetchAll(refetchCacheKeys);
      }
    } catch (_) {
      // Invalidating cache must not change a successful mutation response.
    }
  }

}
