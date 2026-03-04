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
  
  // 1. Add Controllers to capture data
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

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
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _authTab("Login", isLogin, () => setState(() => isLogin = true)),
                      const SizedBox(width: 20),
                      _authTab("Sign up", !isLogin, () => setState(() => isLogin = false)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    isLogin ? "Welcome Back.\nHUGO" : "Create Account.\nJOIN US",
                    style: const TextStyle(fontSize: 32, color: AppColors.white, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  _buildTextField("Email:"),
                  _buildTextField("Password:", obscure: true),
                  const SizedBox(height: 30),
                  Center(
                    child: PrimaryButton(
                      text: isLogin ? "Sign In" : "Continue",
                      onPressed: isLogin ? widget.onLoginSuccess : widget.onRegisterStart,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Keep your _authTab and _buildTextField helpers here)
  Widget _authTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: TextStyle(color: AppColors.white, fontWeight: active ? FontWeight.bold : FontWeight.normal, decoration: active ? TextDecoration.underline : null)),
    );
  }

  Widget _buildTextField(String label, {bool obscure = false}) {
    return TextField(
      obscureText: obscure,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.white)),
      ),
    );
  }
}
