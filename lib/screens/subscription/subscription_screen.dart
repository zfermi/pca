import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_colors.dart';
import 'paypal_payment_screen.dart';
import 'mpesa_payment_screen.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Current plan badge
            _buildCurrentPlanCard(sub),
            const SizedBox(height: 24),

            if (!sub.isPremium) ...[
              // Feature comparison
              _buildFeatureComparison(),
              const SizedBox(height: 24),

              // Pricing cards
              _buildPricingSection(context),
            ] else ...[
              _buildPremiumActiveCard(sub),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(SubscriptionService sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: sub.isPremium
            ? const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: sub.isPremium ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: sub.isPremium
            ? null
            : Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            sub.isPremium ? Icons.workspace_premium : Icons.shield_outlined,
            size: 48,
            color: sub.isPremium ? Colors.amber : AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Current Plan: ${sub.planDisplayName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (sub.isPremium && sub.expiryDisplayText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub.expiryDisplayText,
              style: TextStyle(
                fontSize: 14,
                color: sub.isExpired ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Container(
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
            'Compare Plans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _featureRow('Child profiles', '1', 'Unlimited'),
          _featureRow('Screen time timer', '✓', '✓'),
          _featureRow('Schedule control', '✓', '✓'),
          _featureRow('App blocking', '✗', '✓'),
          _featureRow('Remote monitoring', '✗', '✓'),
          _featureRow('Push notifications', '✗', '✓'),
          _featureRow('Usage history', '✗', '✓'),
        ],
      ),
    );
  }

  Widget _featureRow(String feature, String free, String premium) {
    final premiumHas = premium == '✓' || premium == 'Unlimited';
    final freeHas = free == '✓';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: free == '✗'
                  ? const Icon(Icons.close, color: AppColors.textMuted, size: 18)
                  : freeHas
                      ? const Icon(Icons.check, color: AppColors.success, size: 18)
                      : Text(
                          free,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: premium == '✗'
                  ? const Icon(Icons.close, color: AppColors.textMuted, size: 18)
                  : premiumHas
                      ? premium == 'Unlimited'
                          ? const Text(
                              '∞',
                              style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            )
                          : const Icon(Icons.check, color: AppColors.success, size: 18)
                      : Text(
                          premium,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Upgrade to Premium',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PricingCard(
                title: 'Monthly',
                priceUsd: '\$${SubscriptionService.monthlyPriceUsd.toStringAsFixed(2)}',
                priceKes: 'KSH ${SubscriptionService.monthlyPriceKes.toInt()}',
                period: '/month',
                months: 1,
                isPopular: false,
                onPayPal: () => _startPayPal(context, 1),
                onMpesa: () => _startMpesa(context, 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PricingCard(
                title: 'Yearly',
                priceUsd: '\$${SubscriptionService.yearlyPriceUsd.toStringAsFixed(2)}',
                priceKes: 'KSH ${SubscriptionService.yearlyPriceKes.toInt()}',
                period: '/year',
                months: 12,
                isPopular: true,
                savingsText: 'Save 37%',
                onPayPal: () => _startPayPal(context, 12),
                onMpesa: () => _startMpesa(context, 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumActiveCard(SubscriptionService sub) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 48),
          const SizedBox(height: 16),
          const Text(
            'You have full access to all features!',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _premiumFeatureItem(Icons.people, 'Unlimited child profiles'),
          _premiumFeatureItem(Icons.block, 'Per-app blocking'),
          _premiumFeatureItem(Icons.monitor, 'Remote monitoring'),
          _premiumFeatureItem(Icons.notifications_active, 'Push notifications'),
          _premiumFeatureItem(Icons.history, 'Full usage history'),
        ],
      ),
    );
  }

  Widget _premiumFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _startPayPal(BuildContext context, int months) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayPalPaymentScreen(months: months),
      ),
    );
  }

  void _startMpesa(BuildContext context, int months) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MpesaPaymentScreen(months: months),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String priceUsd;
  final String priceKes;
  final String period;
  final int months;
  final bool isPopular;
  final String? savingsText;
  final VoidCallback onPayPal;
  final VoidCallback onMpesa;

  const _PricingCard({
    required this.title,
    required this.priceUsd,
    required this.priceKes,
    required this.period,
    required this.months,
    required this.isPopular,
    this.savingsText,
    required this.onPayPal,
    required this.onMpesa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppColors.primary : AppColors.cardBorder,
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (isPopular && savingsText != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                savingsText!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            priceUsd,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Text(
            period,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            priceKes,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPayPal,
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('PayPal', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0070BA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onMpesa,
              icon: const Icon(Icons.phone_android, size: 18),
              label: const Text('M-Pesa', style: TextStyle(fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
