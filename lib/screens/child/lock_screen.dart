import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/timer_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/pin_manager.dart';
import '../parent/forgot_pin_screen.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  void _showUnlockDialog(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Parent PIN Required', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'Enter PIN',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.backgroundMid,
                counterText: '',
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
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ForgotPinScreen()),
                  ).then((result) {
                    if (result == true && context.mounted) {
                      context.read<TimerProvider>().clearExpired();
                      WakelockPlus.disable();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  });
                },
                child: const Text('Forgot PIN?', style: TextStyle(fontSize: 13, color: AppColors.primaryLight)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () async {
              final pin = pinController.text;
              final valid = await PinManager.verifyPin(pin);
              if (!dialogContext.mounted) return;
              if (valid) {
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  context.read<TimerProvider>().clearExpired();
                  WakelockPlus.disable();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect PIN'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter parent PIN to unlock')),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3D0000), Color(0xFF1A0000)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.error,
                            AppColors.error.withValues(alpha: 0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.4),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.timer_off, size: 64, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "Time's Up!",
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your TV time has ended for today.\nAsk a parent to unlock.',
                      style: TextStyle(
                        fontSize: 19,
                        color: Color(0xFFFF9E9E),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 220,
                      height: 56,
                      child: FilledButton(
                        autofocus: true,
                        onPressed: () => _showUnlockDialog(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Parent Unlock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
