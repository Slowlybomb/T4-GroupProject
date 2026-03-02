import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/locator.dart';
import 'core/theme/app_colour_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'features/onboarding/view/onboarding_screen.dart';
import 'features/auth/view/auth_screen.dart';
import 'features/dashboard/view/dashboard_screen.dart';

class RowingApp extends StatefulWidget {
  final AuthRepository? authRepository;
  final bool initialOnboardingFinished;

  const RowingApp({
    super.key,
    this.authRepository,
    this.initialOnboardingFinished = false,
  });

  @override
  State<RowingApp> createState() => _RowingAppState();
}

class _RowingAppState extends State<RowingApp> {
  late final AuthRepository _authRepository;
  bool _isOnboardingFinished = false;
  bool _isLoggedIn = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? Locator.authRepository;
    _isOnboardingFinished = widget.initialOnboardingFinished;

    // Restore persisted auth state on app launch.
    _isLoggedIn = _authRepository.isLoggedIn;

    // Keep UI routing in sync with sign-in/sign-out events.
    _authStateSubscription = _authRepository.authStateChanges().listen((event) {
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
                    authRepository: _authRepository,
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
