import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_colors.dart';

/// M-Pesa payment screen — initiates Daraja API STK push via edge function,
/// then polls for confirmation from the callback.
class MpesaPaymentScreen extends StatefulWidget {
  final int months;

  const MpesaPaymentScreen({super.key, required this.months});

  @override
  State<MpesaPaymentScreen> createState() => _MpesaPaymentScreenState();
}

class _MpesaPaymentScreenState extends State<MpesaPaymentScreen> {
  final _phoneController = TextEditingController();
  bool _isProcessing = false;
  bool _stkSent = false;
  bool _paymentComplete = false;
  String? _error;
  String? _checkoutRequestId;
  Timer? _pollTimer;

  double get _amountKes => widget.months == 12
      ? SubscriptionService.yearlyPriceKes
      : SubscriptionService.monthlyPriceKes * widget.months;

  String get _planLabel => widget.months == 12 ? 'Yearly' : 'Monthly';

  @override
  void dispose() {
    _phoneController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendStkPush() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }

    final familyId = context.read<AuthService>().familyId;
    if (familyId == null) {
      setState(() => _error = 'Not linked to a family');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final paymentService = context.read<PaymentService>();
    final result = await paymentService.initiateMpesaStkPush(
      phone: phone,
      amount: _amountKes,
      familyId: familyId,
      months: widget.months,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isProcessing = false;
        _stkSent = true;
        _checkoutRequestId = result.checkoutRequestId;
      });
      // Start polling for payment confirmation
      _startPolling();
    } else {
      setState(() {
        _isProcessing = false;
        _error = result.error;
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_checkoutRequestId == null) return;

      final paymentService = context.read<PaymentService>();
      final status = await paymentService.checkMpesaStatus(_checkoutRequestId!);

      if (!mounted) return;

      if (status.status == 'completed') {
        _pollTimer?.cancel();
        // Refresh subscription state
        await context.read<SubscriptionService>().refreshSubscription();
        if (mounted) {
          setState(() => _paymentComplete = true);
        }
      } else if (status.status == 'failed') {
        _pollTimer?.cancel();
        setState(() {
          _stkSent = false;
          _error = 'Payment was cancelled or failed. Please try again.';
        });
      }
    });

    // Stop polling after 2 minutes
    Future.delayed(const Duration(minutes: 2), () {
      if (mounted && !_paymentComplete && _stkSent) {
        _pollTimer?.cancel();
        setState(() {
          _error = 'Payment timed out. If you completed the payment, it will be activated shortly.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M-Pesa Payment'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _paymentComplete
            ? _buildSuccessView()
            : _stkSent
                ? _buildWaitingView()
                : _buildPhoneInputView(),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
        ),
        const SizedBox(height: 24),
        const Text(
          'Payment Successful!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Premium activated for ${widget.months} month${widget.months > 1 ? "s" : ""}',
          style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Premium $_planLabel Plan',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                  Text(
                    'KSH ${_amountKes.toInt()}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // M-Pesa info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_android, color: Color(0xFF4CAF50), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'M-Pesa Lipa Na M-Pesa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Enter your Safaricom phone number below. You will receive an STK push prompt on your phone to authorize the payment.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Phone input
        const Text(
          'M-Pesa Phone Number',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
          decoration: InputDecoration(
            hintText: '0712345678',
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
              borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            ),
            prefixIcon: const Icon(Icons.phone, color: AppColors.textMuted),
            prefixText: '+254 ',
            prefixStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 17),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isProcessing ? null : _sendStkPush,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Pay KSH ${_amountKes.toInt()} via M-Pesa',
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // STK push sent notice
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.phone_callback, color: Color(0xFF4CAF50), size: 48),
              const SizedBox(height: 12),
              const Text(
                'Check your phone!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'An M-Pesa payment prompt for KSH ${_amountKes.toInt()} has been sent to +254 ${_phoneController.text}.\n\nEnter your M-Pesa PIN on your phone to complete the payment.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Waiting indicator
        const Center(
          child: Column(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color(0xFF4CAF50),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Waiting for payment confirmation...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],

        const SizedBox(height: 24),

        Center(
          child: TextButton(
            onPressed: () {
              _pollTimer?.cancel();
              setState(() {
                _stkSent = false;
                _error = null;
              });
            },
            child: const Text(
              'Try a different number',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}
