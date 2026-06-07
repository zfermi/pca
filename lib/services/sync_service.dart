import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/child_profile.dart';
import '../utils/time_utils.dart';

class SyncService extends ChangeNotifier {
  final bool enabled;
  SupabaseClient? _supabase;
  final _db = DatabaseHelper.instance;

  SupabaseClient get _client => _supabase!;

  String? _familyId;
  String? _deviceId;
  bool _isSyncing = false;
  DateTime? _lastSync;
  RealtimeChannel? _childrenChannel;
  RealtimeChannel? _blockedAppsChannel;
  RealtimeChannel? _activityChannel;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSync => _lastSync;

  SyncService({this.enabled = true}) {
    if (enabled) {
      _supabase = Supabase.instance.client;
    }
  }

  void configure({required String familyId, required String deviceId}) {
    _familyId = familyId;
    _deviceId = deviceId;
  }

  // --- Push local data to Supabase ---

  Future<void> pushChild(ChildProfile child) async {
    if (!enabled || _familyId == null) return;
    try {
      final data = {
        'family_id': _familyId,
        'local_id': child.id,
        'name': child.name,
        'avatar_color': child.avatarColor,
        'daily_limit_minutes': child.dailyLimitMinutes,
        'monday_allowed': child.mondayAllowed,
        'tuesday_allowed': child.tuesdayAllowed,
        'wednesday_allowed': child.wednesdayAllowed,
        'thursday_allowed': child.thursdayAllowed,
        'friday_allowed': child.fridayAllowed,
        'saturday_allowed': child.saturdayAllowed,
        'sunday_allowed': child.sundayAllowed,
        'allowed_start_hour': child.allowedStartHour,
        'allowed_start_minute': child.allowedStartMinute,
        'allowed_end_hour': child.allowedEndHour,
        'allowed_end_minute': child.allowedEndMinute,
        'is_active': child.isActive,
      };

      await _client.from('children').upsert(
        data,
        onConflict: 'family_id,local_id',
      );
    } catch (e) {
      debugPrint('SyncService.pushChild error: $e');
    }
  }

  Future<void> pushUsage(int childId, int usedMinutes, int sessionCount) async {
    if (!enabled || _familyId == null || _deviceId == null) return;
    try {
      final today = TimeUtils.todayString();
      await _client.from('usage_records').upsert({
        'family_id': _familyId,
        'child_local_id': childId,
        'device_id': _deviceId,
        'date': today,
        'used_minutes': usedMinutes,
        'session_count': sessionCount,
      }, onConflict: 'family_id,child_local_id,device_id,date');
    } catch (e) {
      debugPrint('SyncService.pushUsage error: $e');
    }
  }

  Future<void> pushBlockedApps(int childId, List<Map<String, dynamic>> apps) async {
    if (!enabled || _familyId == null) return;
    try {
      await _client.from('blocked_apps')
          .delete()
          .eq('family_id', _familyId!)
          .eq('child_local_id', childId);

      if (apps.isNotEmpty) {
        final rows = apps.map((a) => {
          'family_id': _familyId,
          'child_local_id': childId,
          'package_name': a['packageName'],
          'app_label': a['appLabel'],
        }).toList();
        await _client.from('blocked_apps').insert(rows);
      }
    } catch (e) {
      debugPrint('SyncService.pushBlockedApps error: $e');
    }
  }

  Future<void> pushActivityLog({
    required int childId,
    required String appName,
    String? mediaTitle,
  }) async {
    if (!enabled || _familyId == null || _deviceId == null) return;
    try {
      await _client.from('activity_logs').insert({
        'family_id': _familyId,
        'child_local_id': childId,
        'device_id': _deviceId,
        'app_name': appName,
        'media_title': mediaTitle,
      });
    } catch (e) {
      debugPrint('SyncService.pushActivityLog error: $e');
    }
  }

  // --- Pull remote data (for phone parent dashboard) ---

  Future<List<Map<String, dynamic>>> fetchChildren() async {
    if (_familyId == null) return [];
    try {
      final data = await _client
          .from('children')
          .select()
          .eq('family_id', _familyId!)
          .eq('is_active', true)
          .order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('SyncService.fetchChildren error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsageForDate(int childLocalId, String date) async {
    if (_familyId == null) return [];
    try {
      final data = await _client
          .from('usage_records')
          .select()
          .eq('family_id', _familyId!)
          .eq('child_local_id', childLocalId)
          .eq('date', date);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentUsage(int childLocalId, {int days = 7}) async {
    if (_familyId == null) return [];
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      final data = await _client
          .from('usage_records')
          .select()
          .eq('family_id', _familyId!)
          .eq('child_local_id', childLocalId)
          .gte('date', startDate.toIso8601String().substring(0, 10))
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchBlockedApps(int childLocalId) async {
    if (_familyId == null) return [];
    try {
      final data = await _client
          .from('blocked_apps')
          .select()
          .eq('family_id', _familyId!)
          .eq('child_local_id', childLocalId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentActivity(int childLocalId, {int limit = 20}) async {
    if (_familyId == null) return [];
    try {
      final data = await _client
          .from('activity_logs')
          .select()
          .eq('family_id', _familyId!)
          .eq('child_local_id', childLocalId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Fetch the most recent activity for a child (the "now watching" entry).
  Future<Map<String, dynamic>?> fetchLatestActivity(int childLocalId) async {
    if (!enabled || _familyId == null) return null;
    try {
      final data = await _client
          .from('activity_logs')
          .select()
          .eq('family_id', _familyId!)
          .eq('child_local_id', childLocalId)
          .order('created_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(data);
      if (list.isEmpty) return null;
      // Only show as "live" if created within the last 2 minutes
      final created = DateTime.tryParse(list[0]['created_at'] as String? ?? '');
      if (created != null && DateTime.now().toUtc().difference(created).inMinutes < 2) {
        return list[0];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch latest activity for all children in the family.
  Future<Map<int, Map<String, dynamic>>> fetchLiveActivities() async {
    if (!enabled || _familyId == null) return {};
    try {
      final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      final data = await _client
          .from('activity_logs')
          .select()
          .eq('family_id', _familyId!)
          .gte('created_at', cutoff.toIso8601String())
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      // Group by child_local_id, keep only the latest per child
      final Map<int, Map<String, dynamic>> result = {};
      for (final entry in list) {
        final childId = entry['child_local_id'] as int;
        if (!result.containsKey(childId)) {
          result[childId] = entry;
        }
      }
      return result;
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> fetchDevices() async {
    if (_familyId == null) return [];
    try {
      final data = await _client
          .from('devices')
          .select()
          .eq('family_id', _familyId!)
          .order('last_seen', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // --- Full sync (TV side: push all local data) ---

  Future<void> syncAll() async {
    if (!enabled || _familyId == null) return;
    _isSyncing = true;
    notifyListeners();

    try {
      final children = await _db.getActiveChildren();
      for (final child in children) {
        await pushChild(child);

        final today = TimeUtils.todayString();
        final usage = await _db.getUsageForDate(child.id!, today);
        if (usage != null) {
          await pushUsage(child.id!, usage.usedMinutes, usage.sessionCount);
        }

        final blocked = await _db.getBlockedApps(child.id!);
        await pushBlockedApps(child.id!, blocked);
      }

      _lastSync = DateTime.now();
    } catch (e) {
      debugPrint('SyncService.syncAll error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- Realtime subscriptions (for phone dashboard live updates) ---

  void subscribeToChanges(VoidCallback onUpdate) {
    if (!enabled || _familyId == null) return;

    _childrenChannel = _client.channel('children_changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'children',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: _familyId!,
        ),
        callback: (_) => onUpdate(),
      ).subscribe();

    _blockedAppsChannel = _client.channel('usage_and_activity_changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'usage_records',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: _familyId!,
        ),
        callback: (_) => onUpdate(),
      ).subscribe();

    _activityChannel = _client.channel('activity_log_changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'activity_logs',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'family_id',
          value: _familyId!,
        ),
        callback: (_) => onUpdate(),
      ).subscribe();
  }

  void unsubscribe() {
    _childrenChannel?.unsubscribe();
    _blockedAppsChannel?.unsubscribe();
    _activityChannel?.unsubscribe();
    _childrenChannel = null;
    _blockedAppsChannel = null;
    _activityChannel = null;
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
