import 'dart:async';

import 'package:gondolier/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SignInHandler =
    Future<void> Function({required String email, required String password});
typedef SignUpHandler =
    Future<SignUpResult> Function({
      required String email,
      required String password,
      required String fullName,
      required String emailRedirectTo,
    });

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    bool isLoggedIn = false,
    StreamController<AuthState>? authStateController,
    SignInHandler? onSignIn,
    SignUpHandler? onSignUp,
  }) : _isLoggedIn = isLoggedIn,
       _authStateController =
           authStateController ?? StreamController<AuthState>.broadcast(),
       _onSignIn = onSignIn,
       _onSignUp = onSignUp;

  bool _isLoggedIn;
  final StreamController<AuthState> _authStateController;
  final SignInHandler? _onSignIn;
  final SignUpHandler? _onSignUp;

  int signInCallCount = 0;
  int signUpCallCount = 0;

  String? lastSignInEmail;
  String? lastSignInPassword;

  String? lastSignUpEmail;
  String? lastSignUpPassword;
  String? lastSignUpFullName;
  String? lastSignUpRedirectTo;

  @override
  bool get isLoggedIn => _isLoggedIn;

  set isLoggedIn(bool value) {
    _isLoggedIn = value;
  }

  @override
  Stream<AuthState> authStateChanges() => _authStateController.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCallCount += 1;
    lastSignInEmail = email;
    lastSignInPassword = password;

    if (_onSignIn != null) {
      await _onSignIn(email: email, password: password);
      return;
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String emailRedirectTo,
  }) async {
    signUpCallCount += 1;
    lastSignUpEmail = email;
    lastSignUpPassword = password;
    lastSignUpFullName = fullName;
    lastSignUpRedirectTo = emailRedirectTo;

    if (_onSignUp != null) {
      return _onSignUp(
        email: email,
        password: password,
        fullName: fullName,
        emailRedirectTo: emailRedirectTo,
      );
    }

    return SignUpResult.verificationEmailSent;
  }

  Future<void> emit(AuthState state) async {
    _authStateController.add(state);
    await Future<void>.value();
  }

  Future<void> close() async {
    await _authStateController.close();
  }
}

Session buildTestSession({
  String userId = '11111111-1111-1111-1111-111111111111',
  String accessToken = 'header.payload.signature',
}) {
  return Session.fromJson({
    'access_token': accessToken,
    'token_type': 'bearer',
    'user': {
      'id': userId,
      'app_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  })!;
}
