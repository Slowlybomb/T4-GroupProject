import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/features/onboarding/controller/onboarding_controller.dart';

void main() {
  group('OnboardingController', () {
    test('setters update state and buildProfile returns composed profile', () {
      final controller = OnboardingController();

      // Simulate user progressing through onboarding steps in any order.
      controller.setGender('female');
      controller.setAge(24);
      controller.setWeight(63.5);

      // Final snapshot should include every value set above.
      final profile = controller.buildProfile();

      expect(profile.gender, 'female');
      expect(profile.age, 24);
      expect(profile.weightKg, 63.5);
    });
  });
}
