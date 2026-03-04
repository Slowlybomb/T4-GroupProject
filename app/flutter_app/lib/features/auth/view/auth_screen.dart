import 'package:flutter/material.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../../core/widgets/primarybutton.dart';
import '../widgets/login_clipper.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onRegisterStart;
  const AuthScreen({super.key, required this.onLoginSuccess, required this.onRegisterStart});

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
            child: SingleChildScrollView( // Added scroll to avoid overflow with more fields
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
                  
                  const SizedBox(height: 40), // Replaced Spacer with fixed height for scrolling

                  // 2. Conditional Fields
                  if (!isLogin) ...[
                    _buildTextField("First Name:", controller: _firstNameController),
                    _buildTextField("Last Name:", controller: _lastNameController),
                  ],
                  _buildTextField("Email:", controller: _emailController),
                  _buildTextField("Password:", controller: _passwordController, obscure: true),
                  
                  const SizedBox(height: 30),
                  Center(
                    child: PrimaryButton(
                      text: isLogin ? "Sign In" : "Continue",
                      onPressed: () {
                        if (isLogin) {
                          widget.onLoginSuccess();
                        } else {
                          // Pass data or just trigger the move to Gender screen
                          widget.onRegisterStart();
                        }
                      },
                    ),
                  ),
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

  // Update helper to accept controller
  Widget _buildTextField(String label, {bool obscure = false, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.white)),
        ),
      ),
    );
  }
}
