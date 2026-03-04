import 'package:flutter/material.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String home = '/home';
}

typedef AppRouteBuilder = Widget Function();

Widget buildAppRouteWidget({
  required String route,
  required AppRouteBuilder onboardingBuilder,
  required AppRouteBuilder authBuilder,
  required AppRouteBuilder homeBuilder,
}) {
  switch (route) {
    case AppRoutes.onboarding:
      return onboardingBuilder();
    case AppRoutes.auth:
      return authBuilder();
    case AppRoutes.home:
      return homeBuilder();
    default:
      return onboardingBuilder();
  }
}
