import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/child_profile.dart';
import '../services/activity_monitor_service.dart';
import '../services/platform_timer_service.dart';

class TimerProvider extends ChangeNotifier {
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  int? _activeChildId;
  String? _activeChildName;
  bool _isRunning = false;
  bool _timeExpired = false;
  bool _useNativeService = false;
  ActivityMonitorService? _activityMonitor;

  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  int? get activeChildId => _activeChildId;
  String? get activeChildName => _activeChildName;
  bool get isRunning => _isRunning;
  bool get timeExpired => _timeExpired;
  double get progress =>
      _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0;

  VoidCallback? onFiveMinuteWarning;
  VoidCallback? onOneMinuteWarning;
  VoidCallback? onTimeExpired;

  void setActivityMonitor(ActivityMonitorService monitor) {
    _activityMonitor = monitor;
  }

  Future<void> startTimer({
    required ChildProfile child,
    required int minutes,
    required String pinHash,
  }) async {
    await stopTimer(record: false);
    _activeChildId = child.id;
    _activeChildName = child.name;
    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
    _isRunning = true;
    _timeExpired = false;
    _useNativeService = Platform.isAndroid;

    if (_useNativeService) {
      await PlatformTimerService.startTimer(
        childId: child.id!,
        childName: child.name,
        minutes: minutes,
        pinHash: pinHash,
      );
      // Activate app blocking for this child
      await PlatformTimerService.setActiveChildForBlocking(child.id!);
      await PlatformTimerService.setBlockingEnabled(true);
      // Start activity monitoring for remote dashboard
      _activityMonitor?.startMonitoring(child.id!);
      // Poll the native service for state updates
      _startPolling();
    } else {
      _startDartTimer();
    }

    notifyListeners();
  }

  void _startDartTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();

        if (_remainingSeconds == 300) {
          onFiveMinuteWarning?.call();
        } else if (_remainingSeconds == 60) {
          onOneMinuteWarning?.call();
        }
      } else {
        _timeExpired = true;
        _isRunning = false;
        _timer?.cancel();
        _timer = null;
        _recordUsage();
        onTimeExpired?.call();
        notifyListeners();
      }
    });
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final state = await PlatformTimerService.getTimerState();
      final wasRunning = _isRunning;
      _isRunning = state['isRunning'] == true;
      _remainingSeconds = (state['remainingSeconds'] as int?) ?? 0;
      _totalSeconds = (state['totalSeconds'] as int?) ?? 0;

      if (wasRunning && !_isRunning && _remainingSeconds <= 0) {
        _timeExpired = true;
        _timer?.cancel();
        _timer = null;
        _recordUsage();
        onTimeExpired?.call();
      }

      notifyListeners();
    });
  }

  Future<void> stopTimer({bool record = true}) async {
    if (record && _isRunning && _activeChildId != null) {
      await _recordUsage();
    }

    if (_useNativeService) {
      await PlatformTimerService.stopTimer();
      await PlatformTimerService.setBlockingEnabled(false);
      _activityMonitor?.stopMonitoring();
    }

    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _activeChildId = null;
    _activeChildName = null;
    _remainingSeconds = 0;
    _totalSeconds = 0;
    _timeExpired = false;
    _useNativeService = false;
    notifyListeners();
  }

  Future<void> addBonusTime(int minutes) async {
    if (_useNativeService) {
      await PlatformTimerService.addBonusTime(minutes);
    }
    _remainingSeconds += minutes * 60;
    _totalSeconds += minutes * 60;
    notifyListeners();
  }

  void clearExpired() {
    _timeExpired = false;
    _activeChildId = null;
    _activeChildName = null;
    notifyListeners();
  }

  Future<void> syncWithNativeService() async {
    if (!Platform.isAndroid) return;
    final state = await PlatformTimerService.getTimerState();
    if (state['isRunning'] == true) {
      _isRunning = true;
      _remainingSeconds = (state['remainingSeconds'] as int?) ?? 0;
      _totalSeconds = (state['totalSeconds'] as int?) ?? 0;
      _activeChildId = state['childId'] as int?;
      _activeChildName = state['childName'] as String?;
      _useNativeService = true;
      _startPolling();
      notifyListeners();
    }
  }

  Future<void> _recordUsage() async {
    if (_activeChildId == null) return;
    final usedSeconds = _totalSeconds - _remainingSeconds;
    final usedMinutes = (usedSeconds / 60).ceil();
    if (usedMinutes > 0) {
      await DatabaseHelper.instance.recordUsage(_activeChildId!, usedMinutes);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
