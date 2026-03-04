import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/data/repositories/auth_repository.dart';
import 'package:gondolier/data/repositories/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  SupabaseAuthRepository createRepository({
    SignInWithPassword? signInWithPassword,
    SignUpWithPassword? signUpWithPassword,
    ResendSignUpVerificationEmail? resendSignUpVerificationEmail,
    UpdateAccountDetails? updateAccountDetails,
    CurrentSessionReader? currentSessionReader,
    CurrentUserReader? currentUserReader,
    AuthStateStreamReader? authStateStreamReader,
  }) {
    return SupabaseAuthRepository.test(
      signInWithPassword:
          signInWithPassword ?? ({required email, required password}) async {},
      signUpWithPassword:
          signUpWithPassword ??
          ({
            required email,
            required password,
            required emailRedirectTo,
            required data,
          }) async => AuthResponse(),
      resendSignUpVerificationEmail:
          resendSignUpVerificationEmail ??
          ({required email, required emailRedirectTo}) async {},
      updateAccountDetails:
          updateAccountDetails ??
          ({required fullName, required email, password}) async {},
      currentSessionReader: currentSessionReader ?? () => null,
      currentUserReader: currentUserReader ?? () => null,
      authStateStreamReader:
          authStateStreamReader ?? () => const Stream<AuthState>.empty(),
    );
  }

  group('SupabaseAuthRepository', () {
    test('signIn succeeds when provider call succeeds', () async {
      final repository = createRepository();

      await repository.signIn(
        email: 'user@example.com',
        password: 'password123',
      );
    });

    test('maps AuthException to user-safe signIn message', () async {
      final repository = createRepository(
        signInWithPassword: ({required email, required password}) async {
          throw AuthException('Email not confirmed');
        },
      );

      await expectLater(
        repository.signIn(email: 'user@example.com', password: 'password123'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            'Please verify your email before logging in.',
          ),
        ),
      );
    });

    test('maps otp_expired to verification resend guidance message', () async {
      final repository = createRepository(
        signInWithPassword: ({required email, required password}) async {
          throw const AuthException(
            'Email link is invalid or has expired',
            statusCode: '403',
            code: 'otp_expired',
          );
        },
      );

      await expectLater(
        repository.signIn(email: 'user@example.com', password: 'password123'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            'This verification link is invalid or expired. Request a new verification email.',
          ),
        ),
      );
    });

    test(
      'signUp returns verificationEmailSent when no session is created',
      () async {
        final repository = createRepository(
          signUpWithPassword:
              ({
                required email,
                required password,
                required emailRedirectTo,
                required data,
              }) async => AuthResponse(session: null),
        );

        final result = await repository.signUp(
          email: 'user@example.com',
          password: 'password123',
          fullName: 'Test User',
          emailRedirectTo: 'com.example.flutter_app://login-callback',
        );

        expect(result, SignUpResult.verificationEmailSent);
      },
    );

    test('signUp returns signedIn when a session is created', () async {
      final repository = createRepository(
        signUpWithPassword:
            ({
              required email,
              required password,
              required emailRedirectTo,
              required data,
            }) async => AuthResponse(session: buildTestSession()),
      );

      final result = await repository.signUp(
        email: 'user@example.com',
        password: 'password123',
        fullName: 'Test User',
        emailRedirectTo: 'com.example.flutter_app://login-callback',
      );

      expect(result, SignUpResult.signedIn);
    });

    test(
      'resendSignUpVerificationEmail calls provider with email and redirect',
      () async {
        String? capturedEmail;
        String? capturedRedirectTo;

        final repository = createRepository(
          resendSignUpVerificationEmail:
              ({required email, required emailRedirectTo}) async {
                capturedEmail = email;
                capturedRedirectTo = emailRedirectTo;
              },
        );

        await repository.resendSignUpVerificationEmail(
          email: 'user@example.com',
          emailRedirectTo: 'com.example.flutter_app://login-callback',
        );

        expect(capturedEmail, 'user@example.com');
        expect(capturedRedirectTo, 'com.example.flutter_app://login-callback');
      },
    );

    test('maps AuthException to user-safe resend message', () async {
      final repository = createRepository(
        resendSignUpVerificationEmail:
            ({required email, required emailRedirectTo}) async {
              throw AuthException('over_email_send_rate_limit');
            },
      );

      await expectLater(
        repository.resendSignUpVerificationEmail(
          email: 'user@example.com',
          emailRedirectTo: 'com.example.flutter_app://login-callback',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            'Too many attempts. Please wait and try again.',
          ),
        ),
      );
    });

    test('exposes currentAccountDetails from current user metadata', () async {
      final session = buildTestSession(
        email: 'tester@example.com',
        userMetadata: {'full_name': 'Test User'},
      );
      final repository = createRepository(
        currentUserReader: () => session.user,
      );

      final details = repository.currentAccountDetails;

      expect(details?.email, 'tester@example.com');
      expect(details?.fullName, 'Test User');
    });

    test('updateAccountDetails trims inputs before provider call', () async {
      String? capturedFullName;
      String? capturedEmail;
      String? capturedPassword;

      final repository = createRepository(
        updateAccountDetails:
            ({required fullName, required email, password}) async {
              capturedFullName = fullName;
              capturedEmail = email;
              capturedPassword = password;
            },
      );

      await repository.updateAccountDetails(
        fullName: '  Test User  ',
        email: ' tester@example.com ',
        password: ' password123 ',
      );

      expect(capturedFullName, 'Test User');
      expect(capturedEmail, 'tester@example.com');
      expect(capturedPassword, 'password123');
    });

    test('maps AuthException to user-safe update account message', () async {
      final repository = createRepository(
        updateAccountDetails:
            ({required fullName, required email, password}) async {
              throw AuthException('weak password');
            },
      );

      await expectLater(
        repository.updateAccountDetails(
          fullName: 'Test User',
          email: 'tester@example.com',
          password: '123',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'message',
            'Password must be at least 6 characters.',
          ),
        ),
      );
    });

    test('exposes isLoggedIn and authStateChanges from providers', () async {
      final controller = StreamController<AuthState>.broadcast();
      final repository = createRepository(
        currentSessionReader: () => buildTestSession(),
        currentUserReader: () => buildTestSession().user,
        authStateStreamReader: () => controller.stream,
      );

      expect(repository.isLoggedIn, isTrue);
      expect(repository.authStateChanges(), emitsDone);
      await controller.close();
    });
  });
}
