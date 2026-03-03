import 'package:flutter/material.dart';

import '../../../core/theme/app_colour_theme.dart';
import '../../../data/repositories/auth_repository.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../widgets/login_clipper.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onSignUpSuccess;
  final AuthRepository? authRepository;

  const AuthScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onSignUpSuccess,
    this.authRepository,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: AppColors.oceanBlue),
          Positioned.fill(
            child: ClipPath(
              clipper: LoginClipper(),
              child: Container(color: AppColors.primaryRed),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(30.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _authTab(
                                "Login",
                                isLogin,
                                () => setState(() => isLogin = true),
                              ),
                              const SizedBox(width: 20),
                              _authTab(
                                "Sign up",
                                !isLogin,
                                () => setState(() => isLogin = false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Text(
                            isLogin
                                ? "Welcome Back.\nLOGIN TO YOUR ACCOUNT"
                                : "Create Account.\nJOIN US",
                            style: const TextStyle(
                              fontSize: 32,
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Swap auth forms without losing the surrounding screen style.
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: isLogin
                                ? LoginScreen(
                                    key: const ValueKey('login-form'),
                                    onLoginSuccess: widget.onLoginSuccess,
                                    authRepository: widget.authRepository,
                                  )
                                : SignUpScreen(
                                    key: const ValueKey('signup-form'),
                                    onSignUpSuccess: widget.onSignUpSuccess,
                                    authRepository: widget.authRepository,
                                  ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _authTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          decoration: active ? TextDecoration.underline : null,
        ),
      ),
    );
  }
}
