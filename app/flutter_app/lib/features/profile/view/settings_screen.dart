import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../../core/widgets/primarybutton.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final AuthRepository? authRepository;
  const ProfileSettingsScreen({super.key, this.authRepository});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final AuthRepository _authRepository;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? Locator.authRepository;
    final details = _authRepository.currentAccountDetails;
    _nameController.text = details?.fullName ?? '';
    _emailController.text = details?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final nextPassword = _passwordController.text.trim();
      await _authRepository.updateAccountDetails(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: nextPassword.isEmpty ? null : nextPassword,
      );
      if (!mounted) return;
      setState(() {
        _successMessage = nextPassword.isEmpty
            ? 'Account details updated.'
            : 'Account details and password updated.';
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to update. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    if (s.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    final next = _passwordController.text.trim();
    final confirm = v?.trim() ?? '';
    if (next.isEmpty && confirm.isEmpty) return null;
    if (confirm.isEmpty) return 'Confirm your new password';
    if (confirm != next) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _nameController.text.trim().isEmpty
        ? 'You'
        : _nameController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryRed),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Profile header ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Joined March 2024',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: const [
                      _ProfileStat(label: 'Activities', value: '12'),
                      _VerticalDivider(),
                      _ProfileStat(label: 'Likes', value: '47'),
                      _VerticalDivider(),
                      _ProfileStat(label: 'Followers', value: '38'),
                      _VerticalDivider(),
                      _ProfileStat(label: 'Following', value: '21'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Account details form ────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.strongTextBlack,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      validator: _validateName,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      validator: _validatePassword,
                      decoration: const InputDecoration(
                        labelText: 'New Password (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      validator: _validateConfirmPassword,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Center(
                      child: AbsorbPointer(
                        absorbing: _isSaving,
                        child: PrimaryButton(
                          text: _isSaving ? 'Saving...' : 'Save Changes',
                          onPressed: _save,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets (mirrors UserProfileScreen style) ─────────────────────
class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.grey.shade200);
  }
}
