import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../remote/remote_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _familyCodeController = TextEditingController();
  bool _isSignUp = false;
  bool _showFamilyCode = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _familyCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    final auth = context.read<AuthService>();

    if (_isSignUp) {
      final result = await auth.signUp(email, password);
      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.error);
        return;
      }
      // After sign up, sign in
      final signInResult = await auth.signIn(email, password);
      if (!mounted) return;
      if (!signInResult.success) {
        setState(() => _error = signInResult.error);
        return;
      }
    } else {
      final result = await auth.signIn(email, password);
      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.error);
        return;
      }
    }

    // If logged in but no family linked, show family code input
    if (!auth.isLinkedToFamily) {
      setState(() {
        _showFamilyCode = true;
        _error = null;
      });
      return;
    }

    _goToDashboard();
  }

  Future<void> _joinFamily() async {
    final code = _familyCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter the family code from your TV');
      return;
    }

    final auth = context.read<AuthService>();
    final result = await auth.joinFamily(code);
    if (!mounted) return;
    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }

    await auth.registerDevice('Phone', 'phone');
    if (!mounted) return;

    final sync = context.read<SyncService>();
    sync.configure(familyId: auth.familyId!, deviceId: auth.deviceId!);

    _goToDashboard();
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RemoteDashboardScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _showFamilyCode ? _buildFamilyCodeForm() : _buildLoginForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.shield, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'TV Parental Control',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to monitor your TV remotely',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 14)),
          ),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecoration('Email'),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecoration('Password'),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 24),
        Consumer<AuthService>(
          builder: (_, auth, __) => SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: auth.isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 17)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _isSignUp = !_isSignUp;
            _error = null;
          }),
          child: Text(
            _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
            style: const TextStyle(color: AppColors.primaryLight),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyCodeForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
          child: const Icon(Icons.link, size: 40, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        const Text(
          'Link to Your TV',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the family code shown on your TV app\nto link this phone for remote monitoring.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 14)),
          ),
        TextField(
          controller: _familyCodeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
          ),
          decoration: _inputDecoration('XXXX-XXXX'),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 24),
        Consumer<AuthService>(
          builder: (_, auth, __) => SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: auth.isLoading ? null : _joinFamily,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Link Phone', style: TextStyle(fontSize: 17)),
            ),
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
      fillColor: AppColors.surface,
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
