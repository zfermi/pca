import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SubscriptionPlan { free, premium }

class SubscriptionService extends ChangeNotifier {
  static const _keyPlan = 'subscription_plan';
  static const _keyExpiry = 'subscription_expiry';

  static const int freeChildLimit = 1;
  static const int premiumChildLimit = 99;

  // Pricing
  static const double monthlyPriceUsd = 3.99;
  static const double yearlyPriceUsd = 29.99;
  static const double monthlyPriceKes = 300;
  static const double yearlyPriceKes = 2500;

  final bool enabled;
  SupabaseClient? _supabase;
  String? _familyId;

  SupabaseClient get _client => _supabase!;

  SubscriptionPlan _plan = SubscriptionPlan.free;
  DateTime? _expiryDate;
  bool _isLoading = false;

  SubscriptionPlan get plan => _plan;
  DateTime? get expiryDate => _expiryDate;
  bool get isLoading => _isLoading;
  bool get isPremium => _plan == SubscriptionPlan.premium && !isExpired;
  bool get isExpired =>
      _plan == SubscriptionPlan.premium &&
      _expiryDate != null &&
      _expiryDate!.isBefore(DateTime.now());

  int get childLimit => isPremium ? premiumChildLimit : freeChildLimit;

  SubscriptionService({this.enabled = true}) {
    if (enabled) {
      _supabase = Supabase.instance.client;
    }
  }

  void configure({required String familyId}) {
    _familyId = familyId;
  }

  Future<void> initialize() async {
    // Load cached subscription state
    final prefs = await SharedPreferences.getInstance();
    final planStr = prefs.getString(_keyPlan);
    final expiryStr = prefs.getString(_keyExpiry);

    if (planStr == 'premium') {
      _plan = SubscriptionPlan.premium;
    }
    if (expiryStr != null) {
      _expiryDate = DateTime.tryParse(expiryStr);
    }

    // Sync with server
    await refreshSubscription();
  }

  Future<void> refreshSubscription() async {
    if (!enabled || _familyId == null) return;
    try {
      final data = await _client
          .from('subscriptions')
          .select()
          .eq('family_id', _familyId!)
          .order('created_at', ascending: false)
          .limit(1);

      final results = List<Map<String, dynamic>>.from(data);
      if (results.isNotEmpty) {
        final sub = results[0];
        final planStr = sub['plan'] as String? ?? 'free';
        final expiryStr = sub['expires_at'] as String?;

        _plan = planStr == 'premium'
            ? SubscriptionPlan.premium
            : SubscriptionPlan.free;
        _expiryDate = expiryStr != null ? DateTime.tryParse(expiryStr) : null;

        // Cache locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyPlan, planStr);
        if (expiryStr != null) {
          await prefs.setString(_keyExpiry, expiryStr);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('SubscriptionService.refreshSubscription error: $e');
    }
  }

  /// Activate premium after successful payment verification
  Future<({bool success, String? error})> activatePremium({
    required String paymentMethod,
    required String transactionId,
    required int months,
    required double amount,
    required String currency,
  }) async {
    if (!enabled || _familyId == null) {
      return (success: false, error: 'Not connected');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc();
      // If already premium, extend from current expiry
      final startFrom = (isPremium && _expiryDate != null && _expiryDate!.isAfter(now))
          ? _expiryDate!
          : now;
      final expiresAt = startFrom.add(Duration(days: months * 30));

      await _client.from('subscriptions').insert({
        'family_id': _familyId,
        'plan': 'premium',
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'amount': amount,
        'currency': currency,
        'months': months,
        'starts_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      });

      _plan = SubscriptionPlan.premium;
      _expiryDate = expiresAt;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlan, 'premium');
      await prefs.setString(_keyExpiry, expiresAt.toIso8601String());

      notifyListeners();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a specific feature is available
  bool canUseFeature(PremiumFeature feature) {
    if (isPremium) return true;
    switch (feature) {
      case PremiumFeature.unlimitedChildren:
        return false;
      case PremiumFeature.appBlocking:
        return false;
      case PremiumFeature.remoteMonitoring:
        return false;
      case PremiumFeature.pushNotifications:
        return false;
      case PremiumFeature.basicTimer:
        return true;
      case PremiumFeature.scheduleControl:
        return true;
    }
  }

  String get planDisplayName => isPremium ? 'Premium' : 'Free';

  String get expiryDisplayText {
    if (!isPremium || _expiryDate == null) return '';
    final days = _expiryDate!.difference(DateTime.now()).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }
}

enum PremiumFeature {
  unlimitedChildren,
  appBlocking,
  remoteMonitoring,
  pushNotifications,
  basicTimer,
  scheduleControl,
}
