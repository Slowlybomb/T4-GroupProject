import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_colour_theme.dart';
import 'features/onboarding/view/onboarding_screen.dart';
import 'features/auth/view/auth_screen.dart';
import 'features/dashboard/view/dashboard_screen.dart';

class RowingApp extends StatefulWidget {
  const RowingApp({super.key});

  @override
  State<RowingApp> createState() => _RowingAppState();
}

class _RowingAppState extends State<RowingApp> {
  bool _isOnboardingFinished = false;
  bool _isLoggedIn = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    // Restore persisted auth state on app launch.
    _isLoggedIn = auth.currentSession != null;

    // Keep UI routing in sync with sign-in/sign-out events.
    _authStateSubscription = auth.onAuthStateChange.listen((event) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoggedIn = event.session != null);
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primaryRed,
        fontFamily: 'sans-serif',
      ),
      home: _isOnboardingFinished
          ? (_isLoggedIn
                ? const MainNavigationHub()
                : AuthScreen(
                    onLoginSuccess: () {
                      setState(() => _isLoggedIn = true);
                    },
                    onSignUpSuccess: () {
                      setState(() => _isLoggedIn = true);
                    },
                  ))
          : OnboardingScreen(
              onFinish: () {
                setState(() => _isOnboardingFinished = true);
              },
            ),
    );
  }
}
