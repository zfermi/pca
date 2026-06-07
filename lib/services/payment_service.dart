import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';

/// Handles payment processing via Supabase Edge Functions.
/// M-Pesa: STK Push via Daraja API
/// PayPal: Order creation → approval URL → capture
class PaymentService {
  final bool enabled;
  SupabaseClient? _supabase;

  PaymentService({this.enabled = true}) {
    if (enabled) {
      _supabase = Supabase.instance.client;
    }
  }

  String get _functionsBaseUrl => '${SupabaseConfig.url}/functions/v1';
  String get _anonKey => SupabaseConfig.anonKey;

  // ─── M-Pesa ──────────────────────────────────────────────────────

  /// Initiate M-Pesa STK push to user's phone
  Future<({bool success, String? checkoutRequestId, String? error})>
      initiateMpesaStkPush({
    required String phone,
    required double amount,
    required String familyId,
    required int months,
  }) async {
    if (!enabled) return (success: false, checkoutRequestId: null, error: 'Not available');

    try {
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/mpesa-stk-push'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer ${_supabase!.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'phone': phone,
          'amount': amount,
          'family_id': familyId,
          'months': months,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return (
          success: true,
          checkoutRequestId: data['checkout_request_id'] as String?,
          error: null,
        );
      } else {
        return (
          success: false,
          checkoutRequestId: null,
          error: data['error'] as String? ?? 'STK push failed',
        );
      }
    } catch (e) {
      debugPrint('M-Pesa STK push error: $e');
      return (success: false, checkoutRequestId: null, error: e.toString());
    }
  }

  /// Poll M-Pesa payment status (check if Safaricom callback has been received)
  Future<({String status, String? receipt, String? error})>
      checkMpesaStatus(String checkoutRequestId) async {
    if (!enabled || _supabase == null) {
      return (status: 'unknown', receipt: null, error: 'Not available');
    }

    try {
      final data = await _supabase!
          .from('mpesa_pending')
          .select('status, mpesa_receipt')
          .eq('checkout_request_id', checkoutRequestId)
          .single();

      return (
        status: data['status'] as String? ?? 'pending',
        receipt: data['mpesa_receipt'] as String?,
        error: null,
      );
    } catch (e) {
      return (status: 'unknown', receipt: null, error: e.toString());
    }
  }

  // ─── PayPal ──────────────────────────────────────────────────────

  /// Create a PayPal order and get approval URL
  Future<({bool success, String? orderId, String? approvalUrl, String? error})>
      createPayPalOrder({
    required double amount,
    required String currency,
    required String familyId,
    required int months,
  }) async {
    if (!enabled) {
      return (success: false, orderId: null, approvalUrl: null, error: 'Not available');
    }

    try {
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/paypal-create-order'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer ${_supabase!.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'family_id': familyId,
          'months': months,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return (
          success: true,
          orderId: data['order_id'] as String?,
          approvalUrl: data['approval_url'] as String?,
          error: null,
        );
      } else {
        return (
          success: false,
          orderId: null,
          approvalUrl: null,
          error: data['error'] as String? ?? 'Failed to create order',
        );
      }
    } catch (e) {
      debugPrint('PayPal create order error: $e');
      return (success: false, orderId: null, approvalUrl: null, error: e.toString());
    }
  }

  /// Open PayPal approval URL in browser
  Future<bool> openPayPalApproval(String approvalUrl) async {
    final uri = Uri.parse(approvalUrl);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Capture PayPal order after user approves (called when app receives deep link)
  Future<({bool success, String? transactionId, String? expiresAt, String? error})>
      capturePayPalOrder(String orderId) async {
    if (!enabled) {
      return (success: false, transactionId: null, expiresAt: null, error: 'Not available');
    }

    try {
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/paypal-capture-order'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer ${_supabase!.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'order_id': orderId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return (
          success: true,
          transactionId: data['transaction_id'] as String?,
          expiresAt: data['expires_at'] as String?,
          error: null,
        );
      } else {
        return (
          success: false,
          transactionId: null,
          expiresAt: null,
          error: data['error'] as String? ?? 'Capture failed',
        );
      }
    } catch (e) {
      debugPrint('PayPal capture error: $e');
      return (success: false, transactionId: null, expiresAt: null, error: e.toString());
    }
  }

  /// Check PayPal order status from pending table
  Future<({String status, String? transactionId})>
      checkPayPalStatus(String orderId) async {
    if (!enabled || _supabase == null) {
      return (status: 'unknown', transactionId: null);
    }

    try {
      final data = await _supabase!
          .from('paypal_pending')
          .select('status, transaction_id')
          .eq('order_id', orderId)
          .single();

      return (
        status: data['status'] as String? ?? 'unknown',
        transactionId: data['transaction_id'] as String?,
      );
    } catch (e) {
      return (status: 'unknown', transactionId: null);
    }
  }
}
