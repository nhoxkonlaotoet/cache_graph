import 'model/api_cache_config.dart';
import 'model/api_cache_relationship.dart';

/// Dynamic application hooks used by the cache engine.
///
/// Assign closures rather than values so a Remote Config update is reflected
/// immediately without rebuilding the interceptors.
class ApiCacheDelegate {
  ApiCacheDelegate._();

  static bool Function() isEnabled = () => false;
  static List<ApiCacheConfig> Function() configs = () => const [];
  static List<ApiCacheRelationship> Function() relationships = () => const [];
  static DateTime? Function() clearBefore = () => null;
  static Future<void> Function(Uri)? reFetch;
  static Future<void> Function(dynamic e, StackTrace stack)? logError;
  static Future<void> Function(List<Map<String, Object?>> stats)? logCacheStats;

  static void configure({
    bool Function()? isEnabled,
    List<ApiCacheConfig> Function()? configs,
    List<ApiCacheRelationship> Function()? relationships,
    DateTime? Function()? clearBefore,
    Future<void> Function(Uri)? reFetch,
    Future<void> Function(dynamic e, StackTrace stack)? logError,
    Future<void> Function(List<Map<String, Object?>> stats)? logCacheStats,
  }) {
    ApiCacheDelegate.isEnabled = isEnabled ?? ApiCacheDelegate.isEnabled;
    ApiCacheDelegate.configs = configs ?? ApiCacheDelegate.configs;
    ApiCacheDelegate.relationships =
        relationships ?? ApiCacheDelegate.relationships;
    ApiCacheDelegate.clearBefore = clearBefore ?? ApiCacheDelegate.clearBefore;
    ApiCacheDelegate.reFetch = reFetch ?? ApiCacheDelegate.reFetch;
    ApiCacheDelegate.logError = logError ?? ApiCacheDelegate.logError;
    ApiCacheDelegate.logCacheStats = logCacheStats ?? ApiCacheDelegate.logCacheStats;
  }
}
