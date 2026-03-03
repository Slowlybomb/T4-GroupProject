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
typedef ResendSignUpVerificationEmail =
    Future<void> Function({
      required String email,
      required String emailRedirectTo,
    });
typedef CurrentSessionReader = Session? Function();
typedef AuthStateStreamReader = Stream<AuthState> Function();

class SupabaseAuthRepository implements AuthRepository {
  final SignInWithPassword _signInWithPassword;
  final SignUpWithPassword _signUpWithPassword;
  final ResendSignUpVerificationEmail _resendSignUpVerificationEmail;
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
      _resendSignUpVerificationEmail =
          (({required String email, required String emailRedirectTo}) async {
            await supabaseClient.auth.resend(
              email: email,
              type: OtpType.signup,
              emailRedirectTo: emailRedirectTo,
            );
          }),
      _currentSessionReader = (() => supabaseClient.auth.currentSession),
      _authStateStreamReader = (() => supabaseClient.auth.onAuthStateChange);

  // Dedicated test constructor to inject fake auth behaviors without mocking
  // the entire Supabase client.
  const SupabaseAuthRepository.test({
    required SignInWithPassword signInWithPassword,
    required SignUpWithPassword signUpWithPassword,
    required ResendSignUpVerificationEmail resendSignUpVerificationEmail,
    required CurrentSessionReader currentSessionReader,
    required AuthStateStreamReader authStateStreamReader,
  }) : _signInWithPassword = signInWithPassword,
       _signUpWithPassword = signUpWithPassword,
       _resendSignUpVerificationEmail = resendSignUpVerificationEmail,
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
      throw AuthFailure(_mapAuthErrorMessage(error));
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
      throw AuthFailure(_mapAuthErrorMessage(error));
    } catch (_) {
      throw const AuthFailure('Unable to sign up. Please try again.');
    }
  }

  @override
  Future<void> resendSignUpVerificationEmail({
    required String email,
    required String emailRedirectTo,
  }) async {
    try {
      await _resendSignUpVerificationEmail(
        email: email,
        emailRedirectTo: emailRedirectTo,
      );
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthErrorMessage(error));
    } catch (_) {
      throw const AuthFailure(
        'Unable to resend verification email. Please try again.',
      );
    }
  }

  String _mapAuthErrorMessage(AuthException error) {
    final rawMessage = error.message;
    final message = rawMessage.toLowerCase();
    final code = (error.code ?? '').toLowerCase();

    if (code == 'otp_expired' ||
        message.contains('invalid or has expired') ||
        message.contains('link is invalid') ||
        message.contains('has expired')) {
      return 'This verification link is invalid or expired. Request a new verification email.';
    }

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
