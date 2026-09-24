import 'dart:math';

/// Identifiers that bound cache entries to the current app and login lifecycles.
class ApiCacheSession {
  ApiCacheSession._();

  static final _random = Random.secure();
  static final String appSessionId = _newId();
  static String? _loginSessionId;

  static String? get loginSessionId => _loginSessionId;

  static void startLoginSession() {
    _loginSessionId = _newId();
  }

  static String _newId() => List.generate(
        4,
        (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
      ).join();
}
