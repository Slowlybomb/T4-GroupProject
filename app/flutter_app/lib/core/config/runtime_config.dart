class RuntimeConfig {
  static const String _apiBaseUrlKey = 'API_BASE_URL';
  static const String _supabaseUrlKey = 'SUPABASE_URL';
  static const String _supabaseAnonKeyKey = 'SUPABASE_ANON_KEY';
  static const String _useLocalFeedFallbackKey = 'USE_LOCAL_FEED_FALLBACK';

  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool useLocalFeedFallback;

  const RuntimeConfig._({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.useLocalFeedFallback,
  });

  factory RuntimeConfig.fromEnvironment() {
    // Flutter client config is injected via --dart-define at build/run time.
    return RuntimeConfig._(
      apiBaseUrl: _normalizeBaseUrl(
        const String.fromEnvironment(_apiBaseUrlKey, defaultValue: ''),
      ),
      supabaseUrl: _normalizeBaseUrl(
        const String.fromEnvironment(_supabaseUrlKey, defaultValue: ''),
      ),
      supabaseAnonKey: const String.fromEnvironment(
        _supabaseAnonKeyKey,
        defaultValue: '',
      ),
      useLocalFeedFallback: _parseBool(
        const String.fromEnvironment(
          _useLocalFeedFallbackKey,
          // Default to false so production behavior reflects real backend state.
          defaultValue: 'false',
        ),
      ),
    );
  }

  void validate() {
    final missing = <String>[];

    if (apiBaseUrl.isEmpty) {
      missing.add(_apiBaseUrlKey);
    }
    if (supabaseUrl.isEmpty) {
      missing.add(_supabaseUrlKey);
    }
    if (supabaseAnonKey.isEmpty) {
      missing.add(_supabaseAnonKeyKey);
    }

    if (missing.isEmpty) {
      return;
    }

    throw StateError(
      'Missing required --dart-define values: ${missing.join(', ')}. '
      'Example: flutter run --dart-define=API_BASE_URL=http://localhost:8080 '
      '--dart-define=SUPABASE_URL=https://<project>.supabase.co '
      '--dart-define=SUPABASE_ANON_KEY=<anon_key>',
    );
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static bool _parseBool(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
}
