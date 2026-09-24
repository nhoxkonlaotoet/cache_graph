enum ApiCacheScope { time, appSession, loginSession }

class ApiCacheConfig {
  final List<String> paths;
  final Duration? ttl;
  final ApiCacheScope scope;
  final bool allowStale;

  const ApiCacheConfig({
    required this.paths,
    required this.ttl,
    this.scope = ApiCacheScope.time,
    this.allowStale = false,
  });

  @override
  String toString() {
    return 'ApiCacheConfig{paths: $paths, ttl: $ttl, scope: $scope, allowStale: $allowStale}';
  }

  factory ApiCacheConfig.fromJson(Map<String, dynamic>? json) {
    final ttlSeconds = _asInt(json?['ttlSeconds'] ?? json?['ttl_seconds']);
    final ttlMinutes = _asInt(json?['ttlMinutes'] ?? json?['ttl_minutes']);
    final ttlHours = _asInt(json?['ttlHours'] ?? json?['ttl_hours']);
    return ApiCacheConfig(
      paths: _pathsFrom(json),
      ttl: ttlSeconds != null
          ? Duration(seconds: ttlSeconds)
          : ttlMinutes != null
              ? Duration(minutes: ttlMinutes)
              : ttlHours != null
                  ? Duration(hours: ttlHours)
                  : null,
      scope: _scopeFrom(json?['scope']),
      allowStale: _asBool(json?['allowStale'] ?? json?['allow_stale']),
    );
  }

  bool matches(String requestPath) {
    final normalizedRequestPath = requestPath.replaceFirst(RegExp(r'^/'), '');
    return paths.any(
      (path) => path == '*' || normalizedRequestPath == path.replaceFirst(RegExp(r'^/'), ''),
    );
  }

  bool get isValid =>
      paths.isNotEmpty &&
      (scope != ApiCacheScope.time || (ttl ?? Duration.zero) > Duration.zero);

  static List<String> _pathsFrom(Map<String, dynamic>? json) {
    final configuredPaths = json?['paths'];
    if (configuredPaths is! List) return const [];
    return configuredPaths
        .map((value) => value?.toString().trim() ?? '')
        .where((path) => path.isNotEmpty)
        .toList();
  }

  static ApiCacheScope _scopeFrom(dynamic value) {
    switch (value?.toString().replaceAll('_', '').toLowerCase()) {
      case 'appsession':
        return ApiCacheScope.appSession;
      case 'loginsession':
        return ApiCacheScope.loginSession;
      default:
        return ApiCacheScope.time;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(dynamic value) {
    return value == true || value == 1 || value?.toString().toLowerCase() == 'true';
  }
}
