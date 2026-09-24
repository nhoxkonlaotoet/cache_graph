import 'package:cache_graph/api_cache_delegate.dart';
import 'package:cache_graph/engine/interceptors_cache.dart';
import 'package:cache_graph/model/api_cache_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final allPaths = ApiCacheConfig.fromJson({
    'paths': ['*'],
    'ttlMinutes': 30,
    'scope': 'time',
  });
  final specificPath = ApiCacheConfig.fromJson({
    'paths': ['api/v1/special'],
    'scope': 'appSession',
  });

  setUp(() {
    ApiCacheDelegate.configs = () => [allPaths, specificPath];
  });

  tearDown(() {
    ApiCacheDelegate.configs = () => const [];
  });

  test('wildcard matches every path and specific rule takes priority', () {
    final interceptor = ReadCacheInterceptor();

    expect(allPaths.isValid, isTrue);
    expect(allPaths.matches('/api/v1/other'), isTrue);
    expect(
      interceptor.cacheConfigFor(RequestOptions(path: '/api/v1/other', method: 'GET')),
      same(allPaths),
    );
    expect(
      interceptor.cacheConfigFor(RequestOptions(path: '/api/v1/special', method: 'GET')),
      same(specificPath),
    );
  });

  test('wildcard does not cache write requests', () {
    final interceptor = ReadCacheInterceptor();

    expect(
      interceptor.cacheConfigFor(RequestOptions(path: '/api/v1/other', method: 'POST')),
      isNull,
    );
  });
}
