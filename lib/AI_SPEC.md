# API cache — technical spec for AI/code agents

## Contract

The public integration boundary is `ApiCache` in `api_cache.dart`. Application code must not import `ApiCacheDelegate`, `ApiCacheSqliteStartup`, `ApiCacheResponseDatabase`, `ApiCacheRelationshipDatabase`, or `ApiCacheSession` directly. Internal imports inside this module must be relative to the `api_cache` directory; do not use `package:dmscore/src/modules/api_cache/...`.

## Lifecycle

1. Configure dynamic providers with `ApiCache.configure(...)`. Providers are callbacks, not one-time values; read them at operation time so Remote Config updates take effect.
2. Register `ApiCache.readCacheInterceptor`, `ApiCache.writeCacheInterceptor`, and `ApiCache.staleCacheInterceptor` in Dio. Preserve their relative ordering around the app's retry/error interceptors.
3. After successful login, call `ApiCache.startLoginSession()` and `await ApiCache.openDatabase(id: staffId)`.
4. On logout or account switch, call `await ApiCache.closeDatabase()` before opening another cache DB.
5. After relationship configuration changes, call `await ApiCache.updateApiCacheRelationshipsDatabase()`.

## Data and behavior invariants

- Only `GET` requests are cacheable.
- Cache keys include the normalized path and sorted query parameters; changing key construction is a compatibility change.
- `ApiCacheScope.time` requires a positive TTL. `appSession` and `loginSession` are isolated by their session identifiers.
- Each saved entry stores `expired_date = save_time + config.ttl` (or `NULL` when TTL is absent). At read time the effective expiry is the earlier of the configured TTL boundary and the stored `expired_date`; either boundary makes the entry unavailable.
- A cache hit resolves a synthetic Dio `Response` and sets the internal hit marker; the write interceptor must not write that synthetic response again.
- Cache reads/writes, invalidation, stale fallback, and background refetch are best-effort. They must never turn a successful network response into an error.
- A connection error or HTTP `502`/`503` may be replaced by a matching stale entry with `allowStale = true`; other Dio errors must pass through unchanged.
- Mutation methods (`POST`, `PUT`, `PATCH`, `DELETE`) can invalidate related GET entries using configured relationships and optional body regex matching.
- The cache DB is module-owned and separate from the app's main `getIt` database. Do not reintroduce `DatabaseSqlFeatures` or `getIt` into this module.

## Where to change code

- New cache policy/config field: `model/api_cache_config.dart`, then consume it in the engine.
- New invalidation rule: `model/api_cache_relationship.dart` and `db/api_cache_relationship_database.dart`.
- New schema/table: `db/create_tables.dart`; keep creation in `ApiCacheSqliteStartupMixin`. The cache DB is still pre-release and currently stays at version `1`; add migration/versioning only once the schema is released to users.
- New persistence operation: `db/api_cache_response_database.dart` or the relationship database.
- New app capability: add a callback to `ApiCache.configure`, implement storage/engine usage internally, and wire the callback from the app through `ApiCache` only.
- New interceptor behavior: keep public interceptor instances exposed by `ApiCache`; do not make app code know the concrete interceptor classes.

## Verification checklist

- Run `flutter analyze lib/src/modules/api_cache`.
- Verify no internal import matches `package:dmscore/src/modules/api_cache`.
- Verify app integration references only `ApiCache.*` for cache operations.
- Test cache miss, hit, TTL expiry, stale fallback, mutation invalidation, account switch, Remote Config refresh, and DB close/reopen.
- Preserve relative imports for all files under this directory.
