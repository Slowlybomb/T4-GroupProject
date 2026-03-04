import 'package:flutter/material.dart';
import 'core/theme/app_colour_theme.dart';
import 'features/onboarding/view/onboarding_screen.dart'; 
import 'features/auth/view/auth_screen.dart';
import 'features/dashboard/view/dashboard_screen.dart';
import 'features/auth/view/auth_age_gender_weight.dart'; // We'll create this next

class RowingApp extends StatefulWidget {
  const RowingApp({super.key});

  @override
  State<RowingApp> createState() => _RowingAppState();
}

class _RowingAppState extends State<RowingApp> {
  bool _isOnboardingFinished = false;
  bool _isLoggedIn = false;
  bool _isSettingUpProfile = false;
  // 1. Temporary storage for user data
  Map<String, dynamic> tempUserData = {};
  int _setupStep = 1; // Track current setup screen
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryRed,
        fontFamily: 'sans-serif',
      ),
      home: _getHome(), // Use the helper method here
    );
  }

  Widget _getHome() {
    if (!_isOnboardingFinished) {
      return OnboardingScreen(onFinish: () => setState(() => _isOnboardingFinished = true));
    }

    if (_isLoggedIn) return const MainNavigationHub();

    if (_isSettingUpProfile) {
      // 2. Logic to navigate through setup steps and collect data
      switch (_setupStep) {
        case 1:
          return GenderScreen(onNext: (gender) {
            tempUserData['gender'] = gender;
            setState(() => _setupStep = 2);
          });
        case 2:
          return AgePickerScreen(
            onBack: () => setState(() => _setupStep = 1),
            onNext: (age) {
              tempUserData['age'] = age;
              setState(() => _setupStep = 3);
            },
          );
        case 3:
          return WeightPickerScreen(
            onBack: () => setState(() => _setupStep = 2),
            onNext: (weight) {
              tempUserData['weight'] = weight;
              // 3. Trigger the API call
              _finalizeSignup(); 
            },
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return AuthScreen(
      onLoginSuccess: () => setState(() => _isLoggedIn = true),
      onRegisterStart: () => setState(() => _isSettingUpProfile = true),
    );
  }
Future<void> _finalizeSignup() async {
  // Show a loading spinner if you want
  bool success = true;
  if (success) {
    setState(() {
      _isSettingUpProfile = false;
      _isLoggedIn = true;
    });
  } 
}
}