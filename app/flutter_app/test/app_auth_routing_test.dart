import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/app.dart';
import 'package:gondolier/features/auth/view/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_auth_repository.dart';

void main() {
  const loggedInHomeMarker = 'main-hub-loaded';

  testWidgets('onboarding skip signs in demo account and opens main hub', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(isLoggedIn: false);

    await tester.pumpWidget(
      RowingApp(
        authRepository: authRepository,
        initialOnboardingFinished: false,
        loggedInHome: Scaffold(body: Text(loggedInHomeMarker)),
      ),
    );
    await tester.pump();

    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(authRepository.signInCallCount, 1);
    expect(authRepository.lastSignInEmail, 'test_user_gondalier@gmail.com');
    expect(authRepository.lastSignInPassword, '12345678');
    expect(find.text(loggedInHomeMarker), findsOneWidget);
  });

  testWidgets('routes from AuthScreen to main hub on signedIn auth event', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(isLoggedIn: false);

    await tester.pumpWidget(
      RowingApp(
        authRepository: authRepository,
        initialOnboardingFinished: true,
        loggedInHome: Scaffold(body: Text(loggedInHomeMarker)),
      ),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text(loggedInHomeMarker), findsNothing);

    await authRepository.emit(
      AuthState(AuthChangeEvent.signedIn, buildTestSession()),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text(loggedInHomeMarker), findsOneWidget);

    // Dispose the app subscription before closing the fake stream.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
