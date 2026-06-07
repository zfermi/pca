import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinManager {
  static const _keyPinHash = 'parent_pin_hash';
  static const _keySecurityQuestion = 'security_question';
  static const _keySecurityAnswerHash = 'security_answer_hash';

  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPinHash);
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, _hash(pin));
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  static Future<String?> getStoredHash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPinHash);
  }

  // Security question for PIN recovery
  static Future<void> setSecurityQuestion(String question, String answer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySecurityQuestion, question);
    await prefs.setString(_keySecurityAnswerHash, _hash(answer.trim().toLowerCase()));
  }

  static Future<bool> hasSecurityQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keySecurityQuestion) &&
        prefs.containsKey(_keySecurityAnswerHash);
  }

  static Future<String?> getSecurityQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySecurityQuestion);
  }

  static Future<bool> verifySecurityAnswer(String answer) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keySecurityAnswerHash);
    if (stored == null) return false;
    return stored == _hash(answer.trim().toLowerCase());
  }

  static const securityQuestions = [
    "What is your mother's maiden name?",
    "What was the name of your first pet?",
    "What city were you born in?",
    "What is your favorite movie?",
    "What was your childhood nickname?",
    "What street did you grow up on?",
  ];

  static String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
