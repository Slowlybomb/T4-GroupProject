import 'package:flutter/material.dart';

import '../../../core/locator.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../../core/widgets/primarybutton.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../stats/domain/models/user_stats.dart';

class UserStatsScreen extends StatefulWidget {
  final AuthRepository? authRepository;
  final UserStats userStats;

  const UserStatsScreen({
    super.key,
    this.authRepository,
    this.userStats = _defaultUserStats,
  });

  static const UserStats _defaultUserStats = UserStats(
    weeklyDistanceKm: 0,
    weeklyMinutes: 0,
    trainingLogDateRange: 'Feb 2 - Feb 8, 2026',
    trainingLogEntries: [
      TrainingLogEntry(label: 'M'),
      TrainingLogEntry(label: 'T'),
      TrainingLogEntry(label: '1h', highlighted: true),
      TrainingLogEntry(label: 'T'),
    ],
  );

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
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

    final accountDetails = _authRepository.currentAccountDetails;
    _nameController.text = accountDetails?.fullName ?? '';
    _emailController.text = accountDetails?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveAccountDetails() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

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

      if (!mounted) {
        return;
      }

      setState(() {
        _successMessage = nextPassword.isEmpty
            ? 'Account details updated.'
            : 'Account details and password updated.';
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(
        () => _errorMessage =
            'Unable to update account details. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Name is required';
    }
    if (name.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
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
    final password = value?.trim() ?? '';
    if (password.isEmpty) {
      return null;
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final nextPassword = _passwordController.text.trim();
    final confirmPassword = value?.trim() ?? '';

    if (nextPassword.isEmpty && confirmPassword.isEmpty) {
      return null;
    }

    if (confirmPassword.isEmpty) {
      return 'Confirm your new password';
    }

    if (confirmPassword != nextPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  Widget _buildAccountDetailsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
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
            const SizedBox(height: 14),
            Center(
              child: AbsorbPointer(
                absorbing: _isSaving,
                child: PrimaryButton(
                  text: _isSaving ? 'Saving...' : 'Save Changes',
                  onPressed: _saveAccountDetails,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          "You",
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: CircleAvatar(backgroundColor: Colors.grey, radius: 15),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAccountDetailsSection(),
            _ThisWeekSummary(stats: widget.userStats),
            const Text(
              "More graphs",
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w300),
            ),
            _TrainingLogCard(stats: widget.userStats),
          ],
        ),
      ),
    );
  }
}

// Internal helpers for the Profile Screen
class _ThisWeekSummary extends StatelessWidget {
  final UserStats stats;

  const _ThisWeekSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "This Week",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Row(
            children: [
              Text(
                "Distance: ${stats.weeklyDistanceKm.toStringAsFixed(0)} km  ",
                style: const TextStyle(color: AppColors.textGrey),
              ),
              Text(
                "Time: ${stats.weeklyMinutes} m",
                style: const TextStyle(color: AppColors.textGrey),
              ),
            ],
          ),
          const SizedBox(
            height: 100,
            child: Center(child: Text("--- Graph Placeholder ---")),
          ),
        ],
      ),
    );
  }
}

class _TrainingLogCard extends StatelessWidget {
  final UserStats stats;

  const _TrainingLogCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Training Log",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            stats.trainingLogDateRange,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: stats.trainingLogEntries
                .map((entry) => _TrainingLogEntryAvatar(entry: entry))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _TrainingLogEntryAvatar extends StatelessWidget {
  final TrainingLogEntry entry;

  const _TrainingLogEntryAvatar({required this.entry});

  @override
  Widget build(BuildContext context) {
    if (entry.highlighted) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white,
        child: Text(
          entry.label,
          style: const TextStyle(
            color: AppColors.primaryRed,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 15,
      backgroundColor: Colors.white24,
      child: Text(
        entry.label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
