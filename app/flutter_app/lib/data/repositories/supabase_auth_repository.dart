import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

typedef SignInWithPassword =
    Future<void> Function({required String email, required String password});
typedef SignUpWithPassword =
    Future<AuthResponse> Function({
      required String email,
      required String password,
      required String emailRedirectTo,
      required Map<String, dynamic> data,
    });
typedef CurrentSessionReader = Session? Function();
typedef AuthStateStreamReader = Stream<AuthState> Function();

class SupabaseAuthRepository implements AuthRepository {
  final SignInWithPassword _signInWithPassword;
  final SignUpWithPassword _signUpWithPassword;
  final CurrentSessionReader _currentSessionReader;
  final AuthStateStreamReader _authStateStreamReader;

  SupabaseAuthRepository(SupabaseClient supabaseClient)
    : _signInWithPassword =
          (({required String email, required String password}) => supabaseClient
              .auth
              .signInWithPassword(email: email, password: password)),
      _signUpWithPassword =
          (({
            required String email,
            required String password,
            required String emailRedirectTo,
            required Map<String, dynamic> data,
          }) => supabaseClient.auth.signUp(
            email: email,
            password: password,
            emailRedirectTo: emailRedirectTo,
            data: data,
          )),
      _currentSessionReader = (() => supabaseClient.auth.currentSession),
      _authStateStreamReader = (() => supabaseClient.auth.onAuthStateChange);

  // Dedicated test constructor to inject fake auth behaviors without mocking
  // the entire Supabase client.
  const SupabaseAuthRepository.test({
    required SignInWithPassword signInWithPassword,
    required SignUpWithPassword signUpWithPassword,
    required CurrentSessionReader currentSessionReader,
    required AuthStateStreamReader authStateStreamReader,
  }) : _signInWithPassword = signInWithPassword,
       _signUpWithPassword = signUpWithPassword,
       _currentSessionReader = currentSessionReader,
       _authStateStreamReader = authStateStreamReader;

  @override
  bool get isLoggedIn => _currentSessionReader() != null;

  @override
  Stream<AuthState> authStateChanges() => _authStateStreamReader();

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthErrorMessage(error.message));
    } catch (_) {
      throw const AuthFailure('Unable to sign in. Please try again.');
    }
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String emailRedirectTo,
  }) async {
    try {
      final response = await _signUpWithPassword(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
        data: {'full_name': fullName},
      );

      return response.session == null
          ? SignUpResult.verificationEmailSent
          : SignUpResult.signedIn;
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthErrorMessage(error.message));
    } catch (_) {
      throw const AuthFailure('Unable to sign up. Please try again.');
    }
  }

  String _mapAuthErrorMessage(String rawMessage) {
    final message = rawMessage.toLowerCase();

    // Normalize Supabase/Gotrue wording differences to one UX message.
    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }

    if (message.contains('email not confirmed') ||
        message.contains('email not verified') ||
        message.contains('confirm your email')) {
      return 'Please verify your email before logging in.';
    }

    if (message.contains('too many requests') ||
        message.contains('rate limit') ||
        message.contains('over_email_send_rate_limit')) {
      return 'Too many attempts. Please wait and try again.';
    }

    if (message.isEmpty) {
      return 'Authentication failed. Please try again.';
    }

    return rawMessage;
  }
}
