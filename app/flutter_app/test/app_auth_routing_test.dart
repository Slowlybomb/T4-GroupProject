import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/app.dart';
import 'package:gondolier/features/auth/view/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_auth_repository.dart';

void main() {
  testWidgets('routes from AuthScreen to main hub on signedIn auth event', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository(isLoggedIn: false);

    await tester.pumpWidget(
      RowingApp(
        authRepository: authRepository,
        initialOnboardingFinished: true,
      ),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Feed'), findsNothing);

    await authRepository.emit(
      AuthState(AuthChangeEvent.signedIn, buildTestSession()),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);

    // Dispose the app subscription before closing the fake stream.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
