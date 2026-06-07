import 'dart:async';
import 'package:flutter/foundation.dart';
import 'platform_timer_service.dart';
import 'sync_service.dart';

/// Monitors foreground app activity on TV and pushes logs to Supabase.
/// Runs only on TV side during active child sessions.
class ActivityMonitorService extends ChangeNotifier {
  SyncService? _syncService;
  Timer? _pollTimer;
  int? _activeChildId;
  int _lastPollTimestamp = 0;
  bool _isMonitoring = false;

  // Current state visible to UI
  String? _currentApp;
  String? _currentAppLabel;
  String? _currentMediaTitle;
  String? _currentMediaArtist;

  String? get currentApp => _currentApp;
  String? get currentAppLabel => _currentAppLabel;
  String? get currentMediaTitle => _currentMediaTitle;
  String? get currentMediaArtist => _currentMediaArtist;
  bool get isMonitoring => _isMonitoring;

  void configure(SyncService syncService) {
    _syncService = syncService;
  }

  /// Start monitoring when a child session begins.
  Future<void> startMonitoring(int childId) async {
    _activeChildId = childId;
    _isMonitoring = true;
    _lastPollTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Start native activity tracking
    await PlatformTimerService.startActivityTracking();

    // Poll every 15 seconds for new activities and media info
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());

    notifyListeners();
  }

  /// Stop monitoring when session ends.
  Future<void> stopMonitoring() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isMonitoring = false;
    _activeChildId = null;
    _currentApp = null;
    _currentAppLabel = null;
    _currentMediaTitle = null;
    _currentMediaArtist = null;

    await PlatformTimerService.stopActivityTracking();
    notifyListeners();
  }

  Future<void> _poll() async {
    if (!_isMonitoring || _activeChildId == null) return;

    try {
      // Update media info (triggers native MediaSessionManager check)
      final current = await PlatformTimerService.updateMediaInfo();

      final newApp = current['appLabel'] as String?;
      final newMedia = current['mediaTitle'] as String?;
      final newArtist = current['mediaArtist'] as String?;

      final changed = newApp != _currentAppLabel ||
          newMedia != _currentMediaTitle;

      _currentApp = current['packageName'] as String?;
      _currentAppLabel = newApp;
      _currentMediaTitle = newMedia;
      _currentMediaArtist = newArtist;

      if (changed) {
        notifyListeners();
      }

      // Get completed activities (apps the child switched away from)
      final newActivities =
          await PlatformTimerService.getNewActivities(_lastPollTimestamp);

      if (newActivities.isNotEmpty) {
        _lastPollTimestamp = DateTime.now().millisecondsSinceEpoch;

        // Push each completed activity to Supabase
        for (final activity in newActivities) {
          final appLabel = activity['appLabel'] as String? ?? '';
          final mediaTitle = activity['mediaTitle'] as String?;
          if (appLabel.isNotEmpty) {
            _syncService?.pushActivityLog(
              childId: _activeChildId!,
              appName: appLabel,
              mediaTitle: mediaTitle,
            );
          }
        }
      }

      // Also push the current "now watching" state
      if (_currentAppLabel != null && _currentAppLabel!.isNotEmpty) {
        _syncService?.pushActivityLog(
          childId: _activeChildId!,
          appName: _currentAppLabel!,
          mediaTitle: _currentMediaTitle,
        );
      }
    } catch (e) {
      debugPrint('ActivityMonitorService poll error: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
