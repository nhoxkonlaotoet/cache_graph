part of 'interceptors_cache.dart';

mixin BaseCacheInterceptorMixin on Interceptor {
  ApiCacheResponseDatabase get cacheDatabase;

  bool get isApiCacheEnabled;

  ApiCacheConfig? cacheConfigFor(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return null;
    ApiCacheConfig? allPathsConfig;
    for (final config in ApiCacheDelegate.configs()) {
      if (!config.isValid || !_hasSessionFor(config.scope)) continue;
      if (config.paths.contains('*')) {
        allPathsConfig ??= config;
      } else if (config.matches(options.uri.path)) {
        return config;
      }
    }
    return allPathsConfig;
  }

  bool _hasSessionFor(ApiCacheScope scope) {
    return switch (scope) {
      ApiCacheScope.time || ApiCacheScope.appSession => true,
      ApiCacheScope.loginSession => ApiCacheSession.loginSessionId != null,
    };
  }

  String cacheKeyFor(RequestOptions options) {
    final uri = options.uri;
    final query = <String>{};
    uri.queryParametersAll.forEach((key, values) {
      for (final value in values) {
        query.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
        );
      }
    });
    final sortedQuery = query.toList()..sort();
    final base = uri.hasAuthority ? '${uri.origin}${uri.path}' : uri.path;
    return sortedQuery.isEmpty ? base : '$base?${sortedQuery.join('&')}';
  }

  String cachePathFor(RequestOptions options) => normalizePath(options.uri.path);

  String normalizePath(String path) => path.replaceFirst(RegExp(r'^/'), '');

  String requestBodyFor(RequestOptions options) {
    final data = options.data;
    if (data == null) return '';
    if (data is String) return data;
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  dynamic decodeResponseBody(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  void silentRefetchAll(Iterable<String> cacheKeys) {
    for (final cacheKey in cacheKeys) {
      final uri = Uri.tryParse(cacheKey);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) continue;
      unawaited(_silentRefetch(uri));
    }
  }

  Future<void> _silentRefetch(Uri uri) async {
    try {
      await ApiCacheDelegate.reFetch?.call(uri);
    } catch (_) {
      // A background refresh must never surface an error to the active request.
    }
  }
}
