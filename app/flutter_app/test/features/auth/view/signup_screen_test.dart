import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/core/config/auth_config.dart';
import 'package:gondolier/data/repositories/auth_repository.dart';
import 'package:gondolier/features/auth/view/signup_screen.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  Future<void> pumpSignUpScreen(
    WidgetTester tester, {
    required FakeAuthRepository authRepository,
    required VoidCallback onSignUpSuccess,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignUpScreen(
            authRepository: authRepository,
            onSignUpSuccess: onSignUpSuccess,
          ),
        ),
      ),
    );
  }

  Future<void> fillValidSignUpForm(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Tester',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'password123',
    );
  }

  group('SignUpScreen', () {
    testWidgets('password mismatch validation blocks submit', (tester) async {
      final authRepository = FakeAuthRepository();
      var didSignUp = false;

      await pumpSignUpScreen(
        tester,
        authRepository: authRepository,
        onSignUpSuccess: () => didSignUp = true,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'User',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'password456',
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(authRepository.signUpCallCount, 0);
      expect(didSignUp, isFalse);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows verification info when email confirmation is required', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository(
        onSignUp:
            ({
              required email,
              required password,
              required fullName,
              required emailRedirectTo,
            }) async {
              return SignUpResult.verificationEmailSent;
            },
      );

      await pumpSignUpScreen(
        tester,
        authRepository: authRepository,
        onSignUpSuccess: () {},
      );

      await fillValidSignUpForm(tester);
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(authRepository.signUpCallCount, 1);
      expect(authRepository.lastSignUpRedirectTo, AuthConfig.callbackUrl);
      expect(
        find.text(
          'Account created. Check your email to verify before logging in.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('calls onSignUpSuccess when session is created', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository(
        onSignUp:
            ({
              required email,
              required password,
              required fullName,
              required emailRedirectTo,
            }) async {
              return SignUpResult.signedIn;
            },
      );
      var didSignUp = false;

      await pumpSignUpScreen(
        tester,
        authRepository: authRepository,
        onSignUpSuccess: () => didSignUp = true,
      );

      await fillValidSignUpForm(tester);
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(authRepository.signUpCallCount, 1);
      expect(didSignUp, isTrue);
    });
  });
}
