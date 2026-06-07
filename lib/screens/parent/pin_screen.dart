import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/pin_manager.dart';

class PinScreen extends StatefulWidget {
  final bool isFirstTime;

  const PinScreen({super.key, this.isFirstTime = false});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _pinError;
  String? _confirmError;

  void _setPin() async {
    setState(() { _pinError = null; _confirmError = null; });

    final pin = _pinController.text;
    final confirm = _confirmController.text;

    if (pin.length < 4) {
      setState(() => _pinError = 'PIN must be at least 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _confirmError = 'PINs do not match');
      return;
    }

    await PinManager.setPin(pin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN set successfully'), backgroundColor: AppColors.success),
    );
    Navigator.pop(context);
  }

  InputDecoration _inputDecoration(String label, {String? error}) {
    return InputDecoration(
      labelText: label,
      errorText: error,
      counterText: '',
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
        title: Text(widget.isFirstTime ? 'Set Parent PIN' : 'Change PIN'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 25,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create a PIN to protect parent settings',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, letterSpacing: 6),
                  textAlign: TextAlign.center,
                  decoration: _inputDecoration('Enter PIN', error: _pinError),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, letterSpacing: 6),
                  textAlign: TextAlign.center,
                  decoration: _inputDecoration('Confirm PIN', error: _confirmError),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _setPin,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Set PIN', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
