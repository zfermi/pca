import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../utils/app_colors.dart';

class AccountSetupStep extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const AccountSetupStep({super.key, required this.onComplete, required this.onSkip});

  @override
  State<AccountSetupStep> createState() => _AccountSetupStepState();
}

class _AccountSetupStepState extends State<AccountSetupStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false;
  bool _accountCreated = false;
  String? _familyCode;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();

    // Sign up
    final signUp = await auth.signUp(email, password);
    if (!mounted) return;
    if (!signUp.success) {
      setState(() {
        _error = signUp.error;
        _isLoading = false;
      });
      return;
    }

    // Sign in
    final signIn = await auth.signIn(email, password);
    if (!mounted) return;
    if (!signIn.success) {
      setState(() {
        _error = signIn.error;
        _isLoading = false;
      });
      return;
    }

    // Create family
    final family = await auth.createFamily();
    if (!mounted) return;
    if (!family.success) {
      setState(() {
        _error = family.error;
        _isLoading = false;
      });
      return;
    }

    // Register this TV as a device
    await auth.registerDevice('Living Room TV', 'tv');

    if (mounted) {
      setState(() {
        _isLoading = false;
        _accountCreated = true;
        _familyCode = auth.familyCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _accountCreated ? AppColors.success : AppColors.primary,
                        _accountCreated
                            ? AppColors.success.withValues(alpha: 0.7)
                            : AppColors.primaryDark,
                      ],
                    ),
                  ),
                  child: Icon(
                    _accountCreated ? Icons.check_circle : Icons.cloud,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _accountCreated ? 'Account Created!' : 'Remote Monitoring',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _accountCreated
                      ? 'Install this app on your phone and use the family code below to link it.'
                      : 'Create an account to monitor your TV from your phone. You can also skip this and set it up later.',
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: _accountCreated ? _buildFamilyCodeView() : _buildSignUpForm(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecoration('Email address'),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecoration('Password (6+ characters)'),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton(
            autofocus: true,
            onPressed: _isLoading ? null : _createAccount,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Create Account & Get Code', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: widget.onSkip,
          child: const Text(
            "I'll set this up later",
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyCodeView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Your Family Code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter this code in the phone app to link your devices',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.backgroundMid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: Text(
            _familyCode ?? '',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 4,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            autofocus: true,
            onPressed: widget.onComplete,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.backgroundMid,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
