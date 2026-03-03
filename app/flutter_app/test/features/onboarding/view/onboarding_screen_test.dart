import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/features/onboarding/view/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('supports next/back swipes and finish callback', (
      tester,
    ) async {
      var didFinish = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onGetStarted: () => didFinish = true,
            onSkip: () async {},
          ),
        ),
      );

      expect(find.text('Track Your Rowing'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Join the Community'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Analyze Progress'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      final pageViewSize = tester.getSize(find.byType(PageView));
      await tester.drag(
        find.byType(PageView),
        Offset(pageViewSize.width * 0.7, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pump();

      expect(didFinish, isTrue);
    });
  });
}
