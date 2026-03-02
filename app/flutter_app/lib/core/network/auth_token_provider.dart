import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthTokenProvider {
  String? readAccessToken();
  Future<void> dispose();
}

class SupabaseAuthTokenProvider implements AuthTokenProvider {
  final SupabaseClient _supabaseClient;

  StreamSubscription<AuthState>? _authSubscription;
  String? _cachedAccessToken;

  SupabaseAuthTokenProvider(this._supabaseClient) {
    // Prime cache from current session, then keep it updated via auth stream.
    _cachedAccessToken = _supabaseClient.auth.currentSession?.accessToken;
    _authSubscription = _supabaseClient.auth.onAuthStateChange.listen((event) {
      _cachedAccessToken = event.session?.accessToken;
    });
  }

  @override
  String? readAccessToken() {
    // Pull directly from current session first to avoid stale token usage.
    final latestToken = _supabaseClient.auth.currentSession?.accessToken;
    if (latestToken != null && latestToken.isNotEmpty) {
      _cachedAccessToken = latestToken;
    }
    return _cachedAccessToken;
  }

  @override
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
