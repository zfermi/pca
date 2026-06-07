import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  static const _keyFamilyId = 'family_id';
  static const _keyFamilyCode = 'family_code';
  static const _keyDeviceId = 'device_id';

  final bool enabled;
  SupabaseClient? _supabase;

  SupabaseClient get _client => _supabase!;

  String? _familyId;
  String? _familyCode;
  String? _deviceId;
  bool _isLoading = false;

  String? get familyId => _familyId;
  String? get familyCode => _familyCode;
  String? get deviceId => _deviceId;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => enabled && _client.auth.currentUser != null;
  bool get isLinkedToFamily => _familyId != null;
  User? get currentUser => enabled ? _client.auth.currentUser : null;

  AuthService({this.enabled = true}) {
    if (enabled) {
      _supabase = Supabase.instance.client;
      _client.auth.onAuthStateChange.listen((data) {
        notifyListeners();
      });
    }
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _familyId = prefs.getString(_keyFamilyId);
    _familyCode = prefs.getString(_keyFamilyCode);
    _deviceId = prefs.getString(_keyDeviceId);
    notifyListeners();
  }

  Future<({bool success, String? error})> signUp(String email, String password) async {
    if (!enabled) return (success: false, error: 'Cloud features not available');
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _client.auth.signUp(email: email, password: password);
      if (response.user == null) {
        return (success: false, error: 'Sign up failed. Please try again.');
      }
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    } catch (e) {
      return (success: false, error: e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<({bool success, String? error})> signIn(String email, String password) async {
    if (!enabled) return (success: false, error: 'Cloud features not available');
    _isLoading = true;
    notifyListeners();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return (success: true, error: null);
    } on AuthException catch (e) {
      return (success: false, error: e.message);
    } catch (e) {
      return (success: false, error: e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!enabled) return;
    await _client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFamilyId);
    await prefs.remove(_keyFamilyCode);
    await prefs.remove(_keyDeviceId);
    _familyId = null;
    _familyCode = null;
    _deviceId = null;
    notifyListeners();
  }

  Future<({bool success, String? error})> createFamily() async {
    if (!enabled) return (success: false, error: 'Cloud features not available');
    try {
      final code = _generateFamilyCode();
      final response = await _client.from('families').insert({
        'family_code': code,
        'owner_id': currentUser!.id,
      }).select().single();

      _familyId = response['id'] as String;
      _familyCode = code;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFamilyId, _familyId!);
      await prefs.setString(_keyFamilyCode, _familyCode!);

      notifyListeners();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  Future<({bool success, String? error})> joinFamily(String code) async {
    if (!enabled) return (success: false, error: 'Cloud features not available');
    _isLoading = true;
    notifyListeners();
    try {
      final results = await _client
          .from('families')
          .select()
          .eq('family_code', code.toUpperCase().trim());

      if ((results as List).isEmpty) {
        return (success: false, error: 'Family code not found');
      }

      _familyId = results[0]['id'] as String;
      _familyCode = results[0]['family_code'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyFamilyId, _familyId!);
      await prefs.setString(_keyFamilyCode, _familyCode!);

      notifyListeners();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<({bool success, String? error})> registerDevice(String deviceName, String platform) async {
    if (!enabled) return (success: false, error: 'Cloud features not available');
    if (_familyId == null) return (success: false, error: 'Not linked to a family');
    try {
      final response = await _client.from('devices').insert({
        'family_id': _familyId,
        'device_name': deviceName,
        'platform': platform,
        'user_id': currentUser!.id,
      }).select().single();

      _deviceId = response['id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceId, _deviceId!);

      notifyListeners();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  Future<void> updateDeviceLastSeen() async {
    if (!enabled || _deviceId == null) return;
    try {
      await _client.from('devices').update({
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _deviceId!);
    } catch (_) {}
  }

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    return '${code.substring(0, 4)}-${code.substring(4)}';
  }
}
