import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colour_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onTimeout;
  const SplashScreen({super.key, required this.onTimeout});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), widget.onTimeout);
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      backgroundColor: AppColors.primaryRed,
      body: Center(
        child: Image.asset(
          'assets/img/logo-gondolier.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
