/// Tracks consecutive cache hits per API endpoint and decides when to refresh.
///
/// The caller provides a path and its canonical request key. A request with a
/// different key resets that path's sequence, so different query parameters do
/// not contribute to the same refresh threshold.
class ApiCacheHitRefreshManager {
  final int hitThreshold;
  final Duration window;
  final DateTime Function() _now;
  final Map<String, _ApiCacheHitSequence> _sequencesByPath = {};

  ApiCacheHitRefreshManager({
    this.hitThreshold = 3,
    this.window = const Duration(minutes: 1),
    DateTime Function()? now,
  })  : assert(hitThreshold > 0),
        assert(!window.isNegative && window != Duration.zero),
        _now = now ?? DateTime.now;

  /// Records one real cache hit and returns true when the request must bypass
  /// cache and fetch fresh data. The path sequence is reset after that decision.
  bool shouldRefresh({required String path, required String requestKey}) {
    final now = _now();
    final cutoff = now.subtract(window);
    final sequence = _sequencesByPath[path];
    final hits = sequence == null || sequence.requestKey != requestKey
        ? (_sequencesByPath[path] = _ApiCacheHitSequence(requestKey)).hits
        : sequence.hits;
    hits.removeWhere((hitAt) => !hitAt.isAfter(cutoff));
    hits.add(now);

    if (hits.length < hitThreshold) return false;
    _sequencesByPath.remove(path);
    return true;
  }

  /// Breaks the continuous-hit sequence for an endpoint.
  void reset({required String path}) => _sequencesByPath.remove(path);

  void clear() => _sequencesByPath.clear();
}

class _ApiCacheHitSequence {
  final String requestKey;
  final List<DateTime> hits = [];

  _ApiCacheHitSequence(this.requestKey);
}
