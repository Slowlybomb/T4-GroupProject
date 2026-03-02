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
    return const Scaffold(
      backgroundColor: AppColors.primaryRed,
      body: Center(
        child: Icon(Icons.tsunami, size: 100, color: AppColors.white),
      ),
    );
  }
}