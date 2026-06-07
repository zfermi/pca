import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';

class RemoteChildDetailScreen extends StatefulWidget {
  final Map<String, dynamic> child;

  const RemoteChildDetailScreen({super.key, required this.child});

  @override
  State<RemoteChildDetailScreen> createState() => _RemoteChildDetailScreenState();
}

class _RemoteChildDetailScreenState extends State<RemoteChildDetailScreen> {
  List<Map<String, dynamic>> _usageToday = [];
  List<Map<String, dynamic>> _recentUsage = [];
  List<Map<String, dynamic>> _blockedApps = [];
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, dynamic>? _liveActivity;
  bool _isLoading = true;
  Timer? _liveTimer;

  int get _childLocalId => widget.child['local_id'] as int;
  String get _childName => widget.child['name'] as String? ?? 'Unknown';

  @override
  void initState() {
    super.initState();
    _loadData();
    // Poll live activity every 15 seconds
    _liveTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshLive());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final sync = context.read<SyncService>();
    final today = TimeUtils.todayString();

    final results = await Future.wait([
      sync.fetchUsageForDate(_childLocalId, today),
      sync.fetchRecentUsage(_childLocalId),
      sync.fetchBlockedApps(_childLocalId),
      sync.fetchRecentActivity(_childLocalId),
    ]);

    final liveActivity = await sync.fetchLatestActivity(_childLocalId);

    if (mounted) {
      setState(() {
        _usageToday = results[0];
        _recentUsage = results[1];
        _blockedApps = results[2];
        _recentActivity = results[3];
        _liveActivity = liveActivity;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshLive() async {
    final sync = context.read<SyncService>();
    final liveActivity = await sync.fetchLatestActivity(_childLocalId);
    if (mounted) {
      setState(() => _liveActivity = liveActivity);
    }
  }

  int get _usedMinutesToday {
    int total = 0;
    for (final record in _usageToday) {
      total += (record['used_minutes'] as int?) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final dailyLimit = widget.child['daily_limit_minutes'] as int? ?? 0;
    final remaining = (dailyLimit - _usedMinutesToday).clamp(0, dailyLimit);
    final avatarColor = widget.child['avatar_color'] as int? ?? 0xFF6C63FF;

    return Scaffold(
      appBar: AppBar(
        title: Text(_childName),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Profile header
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(avatarColor),
                          child: Text(
                            _childName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _childName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Now Watching (live activity)
                  if (_liveActivity != null) ...[
                    _buildNowWatchingCard(),
                    const SizedBox(height: 16),
                  ],

                  // Today's usage
                  _buildSection(
                    title: "Today's Usage",
                    icon: Icons.timer,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: dailyLimit > 0 ? _usedMinutesToday / dailyLimit : 0,
                          minHeight: 10,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _usedMinutesToday >= dailyLimit ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Used: ${TimeUtils.formatMinutes(_usedMinutesToday)}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            'Remaining: ${TimeUtils.formatMinutes(remaining)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Schedule
                  _buildSection(
                    title: 'Schedule',
                    icon: Icons.schedule,
                    children: [
                      _infoRow('Daily Limit', TimeUtils.formatMinutes(dailyLimit)),
                      _infoRow('Allowed Hours', _formatAllowedHours()),
                      _infoRow('Allowed Days', _formatAllowedDays()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Blocked apps
                  _buildSection(
                    title: 'Blocked Apps',
                    icon: Icons.block,
                    children: [
                      if (_blockedApps.isEmpty)
                        const Text('No apps blocked', style: TextStyle(color: AppColors.textMuted))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _blockedApps.map((app) => Chip(
                            label: Text(
                              app['app_label'] as String? ?? app['package_name'] as String? ?? '',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            ),
                            backgroundColor: AppColors.error.withValues(alpha: 0.15),
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                          )).toList(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Recent activity
                  _buildSection(
                    title: 'Recent Activity',
                    icon: Icons.history,
                    children: [
                      if (_recentActivity.isEmpty)
                        const Text('No activity recorded', style: TextStyle(color: AppColors.textMuted))
                      else
                        ..._recentActivity.take(10).map((activity) {
                          final appName = activity['app_name'] as String? ?? '';
                          final mediaTitle = activity['media_title'] as String?;
                          final createdAt = activity['created_at'] as String?;
                          final timeStr = createdAt != null
                              ? _formatTimestamp(createdAt)
                              : '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.play_arrow, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(appName,
                                          style: const TextStyle(
                                              color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                                      if (mediaTitle != null)
                                        Text(mediaTitle,
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Text(timeStr,
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Usage history
                  _buildSection(
                    title: 'Usage History',
                    icon: Icons.bar_chart,
                    children: [
                      if (_recentUsage.isEmpty)
                        const Text('No usage recorded', style: TextStyle(color: AppColors.textMuted))
                      else
                        ..._recentUsage.take(7).map((record) {
                          final date = record['date'] as String? ?? '';
                          final minutes = record['used_minutes'] as int? ?? 0;
                          final sessions = record['session_count'] as int? ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(date, style: const TextStyle(color: AppColors.textPrimary))),
                                Text(TimeUtils.formatMinutes(minutes),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const SizedBox(width: 12),
                                Text('$sessions session${sessions == 1 ? '' : 's'}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildNowWatchingCard() {
    final appName = _liveActivity!['app_name'] as String? ?? '';
    final mediaTitle = _liveActivity!['media_title'] as String?;
    final createdAt = _liveActivity!['created_at'] as String?;
    final timeStr = createdAt != null ? _formatTimestamp(createdAt) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Now Watching',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tv, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (mediaTitle != null && mediaTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        mediaTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatAllowedHours() {
    final sh = widget.child['allowed_start_hour'] as int? ?? 8;
    final sm = widget.child['allowed_start_minute'] as int? ?? 0;
    final eh = widget.child['allowed_end_hour'] as int? ?? 20;
    final em = widget.child['allowed_end_minute'] as int? ?? 0;
    String fmt(int h, int m) {
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return m == 0 ? '$h12 $period' : '$h12:${m.toString().padLeft(2, '0')} $period';
    }
    return '${fmt(sh, sm)} - ${fmt(eh, em)}';
  }

  String _formatAllowedDays() {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const dayKeys = [
      'monday_allowed', 'tuesday_allowed', 'wednesday_allowed',
      'thursday_allowed', 'friday_allowed', 'saturday_allowed', 'sunday_allowed',
    ];
    final allowed = <String>[];
    for (int i = 0; i < 7; i++) {
      if (widget.child[dayKeys[i]] == true) {
        allowed.add(dayNames[i]);
      }
    }
    return allowed.length == 7 ? 'Every day' : allowed.join(', ');
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
