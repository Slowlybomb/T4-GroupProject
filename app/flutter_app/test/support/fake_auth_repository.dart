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
typedef ResendSignUpVerificationEmailHandler =
    Future<void> Function({
      required String email,
      required String emailRedirectTo,
    });
typedef UpdateAccountDetailsHandler =
    Future<void> Function({
      required String fullName,
      required String email,
      String? password,
    });

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    bool isLoggedIn = false,
    AccountDetails? currentAccountDetails,
    StreamController<AuthState>? authStateController,
    SignInHandler? onSignIn,
    SignUpHandler? onSignUp,
    ResendSignUpVerificationEmailHandler? onResendSignUpVerificationEmail,
    UpdateAccountDetailsHandler? onUpdateAccountDetails,
  }) : _isLoggedIn = isLoggedIn,
       _currentAccountDetails = currentAccountDetails,
       _authStateController =
           authStateController ?? StreamController<AuthState>.broadcast(),
       _onSignIn = onSignIn,
       _onSignUp = onSignUp,
       _onResendSignUpVerificationEmail = onResendSignUpVerificationEmail,
       _onUpdateAccountDetails = onUpdateAccountDetails;

  bool _isLoggedIn;
  AccountDetails? _currentAccountDetails;
  final StreamController<AuthState> _authStateController;
  final SignInHandler? _onSignIn;
  final SignUpHandler? _onSignUp;
  final ResendSignUpVerificationEmailHandler? _onResendSignUpVerificationEmail;
  final UpdateAccountDetailsHandler? _onUpdateAccountDetails;

  int signInCallCount = 0;
  int signUpCallCount = 0;
  int resendSignUpVerificationEmailCallCount = 0;
  int updateAccountDetailsCallCount = 0;

  String? lastSignInEmail;
  String? lastSignInPassword;

  String? lastSignUpEmail;
  String? lastSignUpPassword;
  String? lastSignUpFullName;
  String? lastSignUpRedirectTo;
  String? lastResendSignUpVerificationEmail;
  String? lastResendSignUpRedirectTo;
  String? lastUpdateAccountFullName;
  String? lastUpdateAccountEmail;
  String? lastUpdateAccountPassword;

  @override
  bool get isLoggedIn => _isLoggedIn;

  set isLoggedIn(bool value) {
    _isLoggedIn = value;
  }

  @override
  AccountDetails? get currentAccountDetails => _currentAccountDetails;

  set currentAccountDetails(AccountDetails? value) {
    _currentAccountDetails = value;
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

  @override
  Future<void> resendSignUpVerificationEmail({
    required String email,
    required String emailRedirectTo,
  }) async {
    resendSignUpVerificationEmailCallCount += 1;
    lastResendSignUpVerificationEmail = email;
    lastResendSignUpRedirectTo = emailRedirectTo;

    if (_onResendSignUpVerificationEmail != null) {
      await _onResendSignUpVerificationEmail(
        email: email,
        emailRedirectTo: emailRedirectTo,
      );
    }
  }

  @override
  Future<void> updateAccountDetails({
    required String fullName,
    required String email,
    String? password,
  }) async {
    updateAccountDetailsCallCount += 1;
    lastUpdateAccountFullName = fullName;
    lastUpdateAccountEmail = email;
    lastUpdateAccountPassword = password;

    if (_onUpdateAccountDetails != null) {
      await _onUpdateAccountDetails(
        fullName: fullName,
        email: email,
        password: password,
      );
      return;
    }

    _currentAccountDetails = AccountDetails(email: email, fullName: fullName);
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
  String email = 'user@example.com',
  Map<String, dynamic>? userMetadata,
  String accessToken = 'header.payload.signature',
}) {
  return Session.fromJson({
    'access_token': accessToken,
    'token_type': 'bearer',
    'user': {
      'id': userId,
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': userMetadata ?? <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': '2026-01-01T00:00:00Z',
    },
  })!;
}
