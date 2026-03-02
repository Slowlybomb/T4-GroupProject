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
        currentSessionReader: () => buildTestSession(),
        authStateStreamReader: () => controller.stream,
      );

      expect(repository.isLoggedIn, isTrue);
      expect(repository.authStateChanges(), emitsDone);
      await controller.close();
    });
  });
}
