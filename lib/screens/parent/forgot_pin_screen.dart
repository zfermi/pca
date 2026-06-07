import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/pin_manager.dart';

class ForgotPinScreen extends StatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  final _answerController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  String? _question;
  bool _verified = false;
  String? _answerError;
  String? _pinError;
  String? _confirmError;
  bool _loading = true;
  bool _noRecovery = false;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    final hasQuestion = await PinManager.hasSecurityQuestion();
    if (!hasQuestion) {
      setState(() { _loading = false; _noRecovery = true; });
      return;
    }
    final question = await PinManager.getSecurityQuestion();
    setState(() { _question = question; _loading = false; });
  }

  void _verifyAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _answerError = 'Please enter your answer');
      return;
    }
    final correct = await PinManager.verifySecurityAnswer(answer);
    if (correct) {
      setState(() { _verified = true; _answerError = null; });
    } else {
      setState(() => _answerError = 'Incorrect answer. Try again.');
    }
  }

  void _resetPin() async {
    setState(() { _pinError = null; _confirmError = null; });

    final pin = _newPinController.text;
    final confirm = _confirmPinController.text;

    if (pin.length < 4) {
      setState(() => _pinError = 'PIN must be at least 4 digits');
      return;
    }
    if (pin.length > 6) {
      setState(() => _pinError = 'PIN must be 6 digits or less');
      return;
    }
    if (pin != confirm) {
      setState(() => _confirmError = 'PINs do not match');
      return;
    }

    await PinManager.setPin(pin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN reset successfully!'), backgroundColor: AppColors.success),
    );
    Navigator.pop(context, true);
  }

  InputDecoration _inputDecoration(String label, {String? error, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      errorText: error,
      counterText: '',
      prefixIcon: prefix,
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      errorStyle: const TextStyle(color: AppColors.error),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset PIN'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _noRecovery
              ? _buildNoRecovery()
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: _verified ? _buildNewPinForm() : _buildQuestionForm(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildNoRecovery() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No Recovery Option Set',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'A security question was not configured during setup. '
              'You\'ll need to reinstall the app to reset your PIN.\n\n'
              'This will erase all child profiles and usage data.',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 25, spreadRadius: 3),
            ],
          ),
          child: const Icon(Icons.help_outline, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'Verify Your Identity',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Answer the security question you set during setup.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Security Question:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Text(_question ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _answerController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecoration('Your answer',
              error: _answerError, prefix: const Icon(Icons.edit, color: AppColors.textMuted)),
          onChanged: (_) => setState(() => _answerError = null),
          onSubmitted: (_) => _verifyAnswer(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _verifyAnswer,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Verify', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.success.withValues(alpha: 0.3), blurRadius: 25, spreadRadius: 3),
            ],
          ),
          child: const Icon(Icons.check_circle, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'Identity Verified!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.success),
        ),
        const SizedBox(height: 8),
        const Text('Now set a new PIN.', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 28),
        TextField(
          controller: _newPinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, color: AppColors.textPrimary),
          autofocus: true,
          decoration: _inputDecoration('New PIN', error: _pinError),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8, color: AppColors.textPrimary),
          decoration: _inputDecoration('Confirm New PIN', error: _confirmError),
          onSubmitted: (_) => _resetPin(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _resetPin,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Reset PIN', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
