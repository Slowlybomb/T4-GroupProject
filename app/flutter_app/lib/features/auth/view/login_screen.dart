import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../../core/widgets/primarybutton.dart';
import '../../../data/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final AuthRepository? authRepository;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.authRepository,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthRepository _authRepository;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? Locator.authRepository;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Block submission until client-side rules pass.
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      // Parent widget controls route/state after successful authentication.
      widget.onLoginSuccess();
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = 'Unable to sign in. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            obscure: true,
            validator: _validatePassword,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 26),
          Center(
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: PrimaryButton(
                text: _isLoading ? 'Signing In...' : 'Sign In',
                onPressed: _login,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        errorStyle: const TextStyle(color: Colors.white),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.white),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}
