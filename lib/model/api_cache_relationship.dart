class ApiCacheRelationship {
  final List<ApiCacheWritePath> writePaths;
  final List<ApiCacheStalePath> stalePaths;

  const ApiCacheRelationship({
    required this.writePaths,
    required this.stalePaths,
  });

  factory ApiCacheRelationship.fromJson(Map<String, dynamic> json) {
    return ApiCacheRelationship(
      writePaths: _writePathsFrom(json['writePaths']),
      stalePaths: _stalePathsFrom(json['stalePaths']),
    );
  }

  bool get isValid => writePaths.isNotEmpty && stalePaths.isNotEmpty;

  static List<ApiCacheWritePath> _writePathsFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .map(ApiCacheWritePath.fromJson)
        .where((path) => path.path.isNotEmpty)
        .toList();
  }

  static List<ApiCacheStalePath> _stalePathsFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .map(ApiCacheStalePath.fromJson)
        .where((path) => path.path.isNotEmpty)
        .toList();
  }
}

class ApiCacheWritePath {
  final String path;
  final String bodyRegex;

  const ApiCacheWritePath({required this.path, this.bodyRegex = ''});

  factory ApiCacheWritePath.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return const ApiCacheWritePath(path: '');
    return ApiCacheWritePath(
      path: json['path']?.toString().trim() ?? '',
      bodyRegex: json['bodyRegex']?.toString().trim() ?? '',
    );
  }
}

class ApiCacheStalePath {
  final String path;
  final bool refetch;

  const ApiCacheStalePath({required this.path, this.refetch = false});

  factory ApiCacheStalePath.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return ApiCacheStalePath(
        path: json['path']?.toString().trim() ?? '',
        refetch: json['refetch'] == true,
      );
    }
    return ApiCacheStalePath(path: json?.toString().trim() ?? '');
  }
}
