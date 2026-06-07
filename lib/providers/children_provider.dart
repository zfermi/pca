import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/child_profile.dart';
import '../models/installed_app.dart';
import '../models/usage_record.dart';
import '../services/platform_timer_service.dart';
import '../services/subscription_service.dart';
import '../services/sync_service.dart';
import '../utils/time_utils.dart';

class ChildrenProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  SyncService? _syncService;
  SubscriptionService? _subscriptionService;
  List<ChildProfile> _children = [];
  bool _isLoading = false;

  void setSyncService(SyncService service) {
    _syncService = service;
  }

  void setSubscriptionService(SubscriptionService service) {
    _subscriptionService = service;
  }

  /// Check if user can add another child profile
  bool get canAddChild {
    if (_subscriptionService == null) return true;
    return _children.length < _subscriptionService!.childLimit;
  }

  /// Check if app blocking is available (premium only)
  bool get canUseAppBlocking {
    if (_subscriptionService == null) return true;
    return _subscriptionService!.canUseFeature(PremiumFeature.appBlocking);
  }

  List<ChildProfile> get children => _children;
  bool get isLoading => _isLoading;

  Future<void> loadChildren() async {
    _isLoading = true;
    notifyListeners();
    _children = await _db.getActiveChildren();
    _isLoading = false;
    notifyListeners();
  }

  Future<ChildProfile?> getChild(int id) async {
    return await _db.getChild(id);
  }

  Future<void> addChild(ChildProfile child) async {
    final insertedId = await _db.insertChild(child);
    await loadChildren();
    final inserted = await _db.getChild(insertedId);
    if (inserted != null) _syncService?.pushChild(inserted);
  }

  Future<void> updateChild(ChildProfile child) async {
    await _db.updateChild(child);
    await loadChildren();
    _syncService?.pushChild(child);
  }

  Future<void> deleteChild(int id) async {
    await _db.deactivateChild(id);
    await loadChildren();
    final child = await _db.getChild(id);
    if (child != null) _syncService?.pushChild(child);
  }

  Future<int> getUsedMinutesToday(int childId) async {
    return await _db.getTotalMinutesForDate(childId, TimeUtils.todayString());
  }

  Future<int> getRemainingMinutesToday(ChildProfile child) async {
    final used = await getUsedMinutesToday(child.id!);
    return (child.dailyLimitMinutes - used).clamp(0, child.dailyLimitMinutes);
  }

  Future<List<UsageRecord>> getRecentUsage(int childId) async {
    return await _db.getRecentUsage(childId);
  }

  Future<void> recordUsage(int childId, int minutes) async {
    await _db.recordUsage(childId, minutes);
    notifyListeners();

    final today = TimeUtils.todayString();
    final usage = await _db.getUsageForDate(childId, today);
    if (usage != null) {
      _syncService?.pushUsage(childId, usage.usedMinutes, usage.sessionCount);
    }
  }

  // App blocking

  Future<List<InstalledApp>> getInstalledApps(int childId) async {
    final rawApps = await PlatformTimerService.getInstalledApps();
    final blockedPackages = await PlatformTimerService.getBlockedApps(childId);
    final blockedSet = blockedPackages.toSet();

    return rawApps.map((map) {
      final app = InstalledApp.fromMap(map);
      app.isBlocked = blockedSet.contains(app.packageName);
      return app;
    }).toList();
  }

  Future<void> setBlockedApps(int childId, List<InstalledApp> blockedApps) async {
    final packages = blockedApps
        .where((a) => a.isBlocked)
        .map((a) => a.packageName)
        .toList();

    await PlatformTimerService.setBlockedApps(childId, packages);

    final dbApps = blockedApps
        .where((a) => a.isBlocked)
        .map((a) => {'packageName': a.packageName, 'appLabel': a.appLabel})
        .toList();
    await _db.setBlockedApps(childId, dbApps);
    _syncService?.pushBlockedApps(childId, dbApps);
  }

  Future<int> getBlockedAppCount(int childId) async {
    return await _db.getBlockedAppCount(childId);
  }

  Future<List<Map<String, dynamic>>> getBlockedAppsList(int childId) async {
    return await _db.getBlockedApps(childId);
  }
}
