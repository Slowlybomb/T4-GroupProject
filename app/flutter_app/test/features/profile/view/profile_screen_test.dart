import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/data/repositories/auth_repository.dart';
import 'package:gondolier/features/profile/view/profile_screen.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  Future<void> pumpProfileScreen(
    WidgetTester tester, {
    required FakeAuthRepository authRepository,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: false),
        home: UserStatsScreen(authRepository: authRepository),
      ),
    );
  }

  group('UserStatsScreen', () {
    testWidgets('save updates account details via repository', (tester) async {
      final authRepository = FakeAuthRepository(
        isLoggedIn: true,
        currentAccountDetails: const AccountDetails(
          email: 'old@example.com',
          fullName: 'Old Name',
        ),
      );

      await pumpProfileScreen(tester, authRepository: authRepository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'New Name',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password (optional)'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'password123',
      );

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(authRepository.updateAccountDetailsCallCount, 1);
      expect(authRepository.lastUpdateAccountFullName, 'New Name');
      expect(authRepository.lastUpdateAccountEmail, 'new@example.com');
      expect(authRepository.lastUpdateAccountPassword, 'password123');
      expect(
        find.text('Account details and password updated.'),
        findsOneWidget,
      );
    });

    testWidgets('password mismatch validation blocks save', (tester) async {
      final authRepository = FakeAuthRepository(
        isLoggedIn: true,
        currentAccountDetails: const AccountDetails(
          email: 'old@example.com',
          fullName: 'Old Name',
        ),
      );

      await pumpProfileScreen(tester, authRepository: authRepository);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'New Name',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password (optional)'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'password456',
      );

      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(authRepository.updateAccountDetailsCallCount, 0);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
