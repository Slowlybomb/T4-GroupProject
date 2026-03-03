import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/data/repositories/auth_repository.dart';
import 'package:gondolier/data/repositories/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  group('SupabaseAuthRepository', () {
    test('signIn succeeds when provider call succeeds', () async {
      final repository = SupabaseAuthRepository.test(
        signInWithPassword: ({required email, required password}) async {},
        signUpWithPassword:
            ({
              required email,
              required password,
              required emailRedirectTo,
              required data,
            }) async => AuthResponse(),
        resendSignUpVerificationEmail:
            ({required email, required emailRedirectTo}) async {},
        currentSessionReader: () => null,
        authStateStreamReader: () => const Stream<AuthState>.empty(),
      );

      await repository.signIn(
        email: 'user@example.com',
        password: 'password123',
      );
    });

    test('maps AuthException to user-safe signIn message', () async {
      final repository = SupabaseAuthRepository.test(
        signInWithPassword: ({required email, required password}) async {
          throw AuthException('Email not confirmed');
        },
        signUpWithPassword:
            ({
              required email,
              required password,
              required emailRedirectTo,
              required data,
            }) async => AuthResponse(),
        resendSignUpVerificationEmail:
            ({required email, required emailRedirectTo}) async {},
        currentSessionReader: () => null,
        authStateStreamReader: () => const Stream<AuthState>.empty(),
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
      final repository = SupabaseAuthRepository.test(
        signInWithPassword: ({required email, required password}) async {
          throw const AuthException(
            'Email link is invalid or has expired',
            statusCode: '403',
            code: 'otp_expired',
          );
        },
        signUpWithPassword:
            ({
              required email,
              required password,
              required emailRedirectTo,
              required data,
            }) async => AuthResponse(),
        resendSignUpVerificationEmail:
            ({required email, required emailRedirectTo}) async {},
        currentSessionReader: () => null,
        authStateStreamReader: () => const Stream<AuthState>.empty(),
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
        final repository = SupabaseAuthRepository.test(
          signInWithPassword: ({required email, required password}) async {},
          signUpWithPassword:
              ({
                required email,
                required password,
                required emailRedirectTo,
                required data,
              }) async => AuthResponse(session: null),
          resendSignUpVerificationEmail:
              ({required email, required emailRedirectTo}) async {},
          currentSessionReader: () => null,
          authStateStreamReader: () => const Stream<AuthState>.empty(),
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
      final repository = SupabaseAuthRepository.test(
        signInWithPassword: ({required email, required password}) async {},
        signUpWithPassword:
            ({
              required email,
              required password,
              required emailRedirectTo,
              required data,
            }) async => AuthResponse(session: buildTestSession()),
        resendSignUpVerificationEmail:
            ({required email, required emailRedirectTo}) async {},
        currentSessionReader: () => null,
        authStateStreamReader: () => const Stream<AuthState>.empty(),
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

        final repository = SupabaseAuthRepository.test(
          signInWithPassword: ({required email, required password}) async {},
          signUpWithPassword:
              ({
                required email,
                required password,
                required emailRedirectTo,
                required data,
              }) async => AuthResponse(),
          resendSignUpVerificationEmail:
              ({required email, required emailRedirectTo}) async {
                capturedEmail = email;
                capturedRedirectTo = emailRedirectTo;
              },
          currentSessionReader: () => null,
          authStateStreamReader: () => const Stream<AuthState>.empty(),
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
      final repository = SupabaseAuthRepository.test(
        signInWithPassword: ({required email, required password}) async {},
        signUpWithPassword:
            ({
              required email,
              required password,
              required emailRedirectTo,
              required data,
            }) async => AuthResponse(),
        resendSignUpVerificationEmail:
            ({required email, required emailRedirectTo}) async {
              throw AuthException('over_email_send_rate_limit');
            },
        currentSessionReader: () => null,
        authStateStreamReader: () => const Stream<AuthState>.empty(),
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

    test('exposes isLoggedIn and authStateChanges from providers', () async {
      final controller = StreamController<AuthState>.broadcast();
      final repository = SupabaseAuthRepository.test(
        signInWithPassword: ({required email, required password}) async {},
        signUpWithPassword:
            ({
              required email,
              required password,
              required emailRedirectTo,
              required data,
            }) async => AuthResponse(),
        resendSignUpVerificationEmail:
            ({required email, required emailRedirectTo}) async {},
        currentSessionReader: () => buildTestSession(),
        authStateStreamReader: () => controller.stream,
      );

      expect(repository.isLoggedIn, isTrue);
      expect(repository.authStateChanges(), emitsDone);
      await controller.close();
    });
  });
}
