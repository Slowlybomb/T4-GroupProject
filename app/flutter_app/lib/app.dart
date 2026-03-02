import 'package:flutter/material.dart';
import 'core/theme/app_colour_theme.dart';
import 'features/onboarding/view/onboarding_screen.dart'; 
import 'features/auth/view/auth_screen.dart';
import 'features/dashboard/view/dashboard_screen.dart'; // Import your main screen

class RowingApp extends StatefulWidget {
  const RowingApp({super.key});

  @override
  State<RowingApp> createState() => _RowingAppState();
}

class _RowingAppState extends State<RowingApp> {
  bool _isOnboardingFinished = false;
  bool _isLoggedIn = false; // 1. DECLARE THIS VARIABLE

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryRed,
        fontFamily: 'sans-serif',
      ),
      // 2. UPDATE THIS LOGIC TO CHECK _isLoggedIn
      home: _isOnboardingFinished
          ? (_isLoggedIn
              ? const MainNavigationHub() // Go here if logged in
              : AuthScreen(
                  onLoginSuccess: () {
                    setState(() => _isLoggedIn = true); 
                  },
                  onRegisterStart: () {
                    // Eventually this might lead to onboarding setup screens
                    setState(() => _isLoggedIn = true);
                  },
                ))
          : OnboardingScreen(onFinish: () {
              setState(() => _isOnboardingFinished = true);
            }),
    );
  }
}