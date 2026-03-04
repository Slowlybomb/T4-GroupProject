import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart' hide Locator;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/locator.dart';
import '../data/repositories/auth_repository.dart';
import '../features/auth/view/auth_screen.dart';
import '../features/onboarding/view/onboarding_screen.dart';
import 'providers.dart';
import 'routes.dart';
import 'shell/main_navigation_shell.dart';
import 'theme.dart';

class RowingApp extends StatefulWidget {
  final AuthRepository? authRepository;
  final AppDependencies? appDependencies;
  final bool initialOnboardingFinished;
  final Widget? loggedInHome;

  const RowingApp({
    super.key,
    this.authRepository,
    this.appDependencies,
    this.initialOnboardingFinished = false,
    this.loggedInHome,
  });

  @override
  State<RowingApp> createState() => _RowingAppState();
}

class _RowingAppState extends State<RowingApp> {
  static const _demoAccountEmail = 'test_user_gondalier@gmail.com';
  static const _demoAccountPassword = '12345678';

  late final AuthRepository _authRepository;
  AppDependencies? _appDependencies;
  bool _isOnboardingFinished = false;
  bool _isLoggedIn = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();

    // Tests can pass explicit dependencies; production resolves from Locator.
    _appDependencies = widget.appDependencies ?? Locator.maybeDependencies;
    _authRepository =
        widget.authRepository ??
        _appDependencies?.authRepository ??
        Locator.authRepository;

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

  void _completeOnboarding() {
    setState(() => _isOnboardingFinished = true);
  }

  Future<void> _loginWithDemoAccount() async {
    // Onboarding "Skip" routes through a safe demo account for showcases.
    await _authRepository.signIn(
      email: _demoAccountEmail,
      password: _demoAccountPassword,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isOnboardingFinished = true;
      _isLoggedIn = true;
    });
  }

  String _resolveRoute() {
    if (!_isOnboardingFinished) {
      return AppRoutes.onboarding;
    }
    if (!_isLoggedIn) {
      return AppRoutes.auth;
    }
    return AppRoutes.home;
  }

  Widget _buildRouteWidget() {
    final route = _resolveRoute();
    // Centralized route mapping keeps app-level navigation wiring in one place.
    return buildAppRouteWidget(
      route: route,
      onboardingBuilder: () => OnboardingScreen(
        onGetStarted: _completeOnboarding,
        onSkip: _loginWithDemoAccount,
      ),
      authBuilder: () => AuthScreen(
        authRepository: _authRepository,
        onLoginSuccess: () {
          setState(() => _isLoggedIn = true);
        },
        onSignUpSuccess: () {
          setState(() => _isLoggedIn = true);
        },
      ),
      homeBuilder: () => widget.loggedInHome ?? const MainNavigationHub(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialApp = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _buildRouteWidget(),
    );

    final dependencies = _appDependencies;
    if (dependencies == null) {
      // Widget tests can run without bootstrapping full app dependencies.
      return materialApp;
    }

    // Root providers are attached once here and consumed by feature modules.
    return MultiProvider(
      providers: createAppProviders(dependencies),
      child: materialApp,
    );
  }
}
