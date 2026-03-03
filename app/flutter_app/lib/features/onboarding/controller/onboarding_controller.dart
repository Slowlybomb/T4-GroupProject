import 'package:flutter/material.dart';

import '../domain/models/onboarding_profile.dart';

class OnboardingController extends ChangeNotifier {
  // Fields are intentionally nullable because current UI may skip these steps.
  String? _gender;
  int? _age;
  double? _weightKg;

  String? get gender => _gender;
  int? get age => _age;
  double? get weightKg => _weightKg;

  void setGender(String gender) {
    if (_gender == gender) {
      return;
    }

    _gender = gender;
    notifyListeners();
  }

  void setAge(int age) {
    if (_age == age) {
      return;
    }

    _age = age;
    notifyListeners();
  }

  void setWeight(double weightKg) {
    if (_weightKg == weightKg) {
      return;
    }

    _weightKg = weightKg;
    notifyListeners();
  }

  OnboardingProfile buildProfile() {
    // Snapshot current onboarding selections into a typed domain model.
    return OnboardingProfile(gender: _gender, age: _age, weightKg: _weightKg);
  }
}
