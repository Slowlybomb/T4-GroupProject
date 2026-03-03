import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/data/repositories/auth_repository.dart';
import 'package:gondolier/features/auth/view/login_screen.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    required FakeAuthRepository authRepository,
    required VoidCallback onLoginSuccess,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: Scaffold(
          body: LoginScreen(
            authRepository: authRepository,
            onLoginSuccess: onLoginSuccess,
          ),
        ),
      ),
    );
  }

  group('LoginScreen', () {
    testWidgets('empty form blocks submit', (tester) async {
      final authRepository = FakeAuthRepository();
      var didLogin = false;

      await pumpLoginScreen(
        tester,
        authRepository: authRepository,
        onLoginSuccess: () => didLogin = true,
      );

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(authRepository.signInCallCount, 0);
      expect(didLogin, isFalse);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('valid form trims email and calls onLoginSuccess', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      var didLogin = false;

      await pumpLoginScreen(
        tester,
        authRepository: authRepository,
        onLoginSuccess: () => didLogin = true,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        ' user@example.com ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(authRepository.signInCallCount, 1);
      expect(authRepository.lastSignInEmail, 'user@example.com');
      expect(didLogin, isTrue);
    });

    testWidgets('renders mapped auth error message', (tester) async {
      final authRepository = FakeAuthRepository(
        onSignIn: ({required email, required password}) async {
          throw const AuthFailure(
            'Please verify your email before logging in.',
          );
        },
      );

      await pumpLoginScreen(
        tester,
        authRepository: authRepository,
        onLoginSuccess: () {},
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please verify your email before logging in.'),
        findsOneWidget,
      );
    });

    testWidgets('loading state prevents duplicate submit taps', (tester) async {
      final completer = Completer<void>();
      final authRepository = FakeAuthRepository(
        onSignIn: ({required email, required password}) async {
          await completer.future;
        },
      );

      await pumpLoginScreen(
        tester,
        authRepository: authRepository,
        onLoginSuccess: () {},
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.tap(find.text('Signing In...'), warnIfMissed: false);
      await tester.pump();

      expect(authRepository.signInCallCount, 1);

      completer.complete();
      await tester.pumpAndSettle();
    });
  });
}
