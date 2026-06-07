import 'dart:io';
import 'package:flutter/services.dart';

class PlatformTimerService {
  static const _channel = MethodChannel('com.parentalcontrol.tvpca/timer');

  static bool get isAndroid => Platform.isAndroid;

  static Future<bool> startTimer({
    required int childId,
    required String childName,
    required int minutes,
    required String pinHash,
  }) async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('startTimer', {
        'childId': childId,
        'childName': childName,
        'minutes': minutes,
        'pinHash': pinHash,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopTimer() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('stopTimer');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> addBonusTime(int minutes) async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('addBonusTime', {
        'minutes': minutes,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getTimerState() async {
    if (!isAndroid) {
      return {
        'isRunning': false,
        'remainingSeconds': 0,
        'totalSeconds': 0,
        'childId': -1,
        'childName': '',
      };
    }
    try {
      final result = await _channel.invokeMethod('getTimerState');
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return {
        'isRunning': false,
        'remainingSeconds': 0,
        'totalSeconds': 0,
        'childId': -1,
        'childName': '',
      };
    }
  }

  static Future<bool> hasOverlayPermission() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('hasOverlayPermission');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isTvDevice() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('isTvDevice');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestOverlayPermission() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('requestOverlayPermission');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> dismissOverlay() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('dismissOverlay');
    } catch (_) {}
  }

  // App blocking methods

  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    if (!isAndroid) return [];
    try {
      final result = await _channel.invokeMethod('getInstalledApps');
      return List<Map<String, dynamic>>.from(
        (result as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<bool> setBlockedApps(int childId, List<String> packages) async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('setBlockedApps', {
        'childId': childId,
        'packages': packages,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> getBlockedApps(int childId) async {
    if (!isAndroid) return [];
    try {
      final result = await _channel.invokeMethod('getBlockedApps', {
        'childId': childId,
      });
      return List<String>.from(result);
    } catch (_) {
      return [];
    }
  }

  static Future<bool> setActiveChildForBlocking(int childId) async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('setActiveChildForBlocking', {
        'childId': childId,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setBlockingEnabled(bool enabled) async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('setBlockingEnabled', {
        'enabled': enabled,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBlockingEnabled() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('isBlockingEnabled');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAccessibilityEnabled() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestAccessibilityPermission() async {
    if (!isAndroid) return false;
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> dismissBlockerOverlay() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('dismissBlockerOverlay');
    } catch (_) {}
  }

  // Activity tracking methods

  static Future<bool> startActivityTracking() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('startActivityTracking');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopActivityTracking() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod('stopActivityTracking');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getCurrentActivity() async {
    if (!isAndroid) return {};
    try {
      final result = await _channel.invokeMethod('getCurrentActivity');
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getActivityHistory({int limit = 20}) async {
    if (!isAndroid) return [];
    try {
      final result = await _channel.invokeMethod('getActivityHistory', {
        'limit': limit,
      });
      return List<Map<String, dynamic>>.from(
        (result as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getNewActivities(int sinceTimestamp) async {
    if (!isAndroid) return [];
    try {
      final result = await _channel.invokeMethod('getNewActivities', {
        'sinceTimestamp': sinceTimestamp,
      });
      return List<Map<String, dynamic>>.from(
        (result as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateMediaInfo() async {
    if (!isAndroid) return {};
    try {
      final result = await _channel.invokeMethod('updateMediaInfo');
      return Map<String, dynamic>.from(result);
    } catch (_) {
      return {};
    }
  }
}
