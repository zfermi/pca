import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_colors.dart';

/// PayPal payment screen — creates order via edge function,
/// opens PayPal approval URL in browser, then captures payment on return.
class PayPalPaymentScreen extends StatefulWidget {
  final int months;

  const PayPalPaymentScreen({super.key, required this.months});

  @override
  State<PayPalPaymentScreen> createState() => _PayPalPaymentScreenState();
}

class _PayPalPaymentScreenState extends State<PayPalPaymentScreen>
    with WidgetsBindingObserver {
  bool _isProcessing = false;
  bool _waitingForApproval = false;
  bool _paymentComplete = false;
  String? _error;
  String? _orderId;
  Timer? _pollTimer;

  double get _amount => widget.months == 12
      ? SubscriptionService.yearlyPriceUsd
      : SubscriptionService.monthlyPriceUsd * widget.months;

  String get _planLabel => widget.months == 12 ? 'Yearly' : 'Monthly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  // When user returns from PayPal browser, try to capture the order
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForApproval && _orderId != null) {
      _captureOrder();
    }
  }

  Future<void> _createOrder() async {
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
    final result = await paymentService.createPayPalOrder(
      amount: _amount,
      currency: 'USD',
      familyId: familyId,
      months: widget.months,
    );

    if (!mounted) return;

    if (result.success && result.approvalUrl != null) {
      _orderId = result.orderId;

      // Open PayPal in browser
      final opened = await paymentService.openPayPalApproval(result.approvalUrl!);
      if (opened) {
        setState(() {
          _isProcessing = false;
          _waitingForApproval = true;
        });
      } else {
        setState(() {
          _isProcessing = false;
          _error = 'Could not open PayPal. Please try again.';
        });
      }
    } else {
      setState(() {
        _isProcessing = false;
        _error = result.error;
      });
    }
  }

  Future<void> _captureOrder() async {
    if (_orderId == null) return;

    setState(() {
      _isProcessing = true;
      _waitingForApproval = false;
      _error = null;
    });

    final paymentService = context.read<PaymentService>();
    final result = await paymentService.capturePayPalOrder(_orderId!);

    if (!mounted) return;

    if (result.success) {
      // Refresh subscription state
      await context.read<SubscriptionService>().refreshSubscription();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _paymentComplete = true;
        });
      }
    } else {
      setState(() {
        _isProcessing = false;
        _error = result.error ?? 'Payment capture failed. If you completed payment, it will be activated shortly.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayPal Payment'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _paymentComplete
            ? _buildSuccessView()
            : _waitingForApproval
                ? _buildWaitingView()
                : _buildOrderView(),
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

  Widget _buildOrderView() {
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
                    '\$${_amount.toStringAsFixed(2)}',
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

        // PayPal explanation
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0070BA).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0070BA).withValues(alpha: 0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payment, color: Color(0xFF0070BA), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'PayPal Checkout',
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
                'You will be redirected to PayPal to complete your payment securely. After approval, your premium subscription will be activated automatically.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _isProcessing ? null : _createOrder,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_browser),
            label: Text(
              _isProcessing ? 'Creating order...' : 'Pay with PayPal',
              style: const TextStyle(fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0070BA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0070BA).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0070BA).withValues(alpha: 0.3)),
          ),
          child: const Column(
            children: [
              Icon(Icons.open_in_browser, color: Color(0xFF0070BA), size: 48),
              SizedBox(height: 16),
              Text(
                'Complete payment in PayPal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'A PayPal checkout window has been opened. Complete your payment there, then return to this app.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Center(
          child: Column(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color(0xFF0070BA),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Waiting for you to return...',
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

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _isProcessing ? null : _captureOrder,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0070BA),
              side: const BorderSide(color: Color(0xFF0070BA)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("I've completed payment", style: TextStyle(fontSize: 15)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _waitingForApproval = false;
                _error = null;
              });
            },
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
      ],
    );
  }
}
