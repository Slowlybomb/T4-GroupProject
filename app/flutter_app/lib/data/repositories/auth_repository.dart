import 'package:supabase_flutter/supabase_flutter.dart';

enum SignUpResult { signedIn, verificationEmailSent }

class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}

abstract class AuthRepository {
  bool get isLoggedIn;

  Stream<AuthState> authStateChanges();

  Future<void> signIn({required String email, required String password});

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String emailRedirectTo,
  });

  Future<void> resendSignUpVerificationEmail({
    required String email,
    required String emailRedirectTo,
  });
}
