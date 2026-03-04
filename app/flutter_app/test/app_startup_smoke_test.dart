import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/app.dart';

import 'support/fake_auth_repository.dart';

void main() {
  testWidgets('fresh launch shows onboarding first screen', (tester) async {
    final authRepository = FakeAuthRepository(isLoggedIn: false);

    await tester.pumpWidget(
      RowingApp(
        authRepository: authRepository,
        // Fresh install path should start in onboarding.
        initialOnboardingFinished: false,
        loggedInHome: const Scaffold(body: Text('home')),
      ),
    );
    await tester.pump();

    expect(find.text('Track Your Rowing'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
