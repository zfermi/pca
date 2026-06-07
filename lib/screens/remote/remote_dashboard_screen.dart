import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/subscription_service.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';
import '../auth/login_screen.dart';
import 'notification_history_screen.dart';
import '../subscription/subscription_screen.dart';
import 'remote_child_detail_screen.dart';

class RemoteDashboardScreen extends StatefulWidget {
  const RemoteDashboardScreen({super.key});

  @override
  State<RemoteDashboardScreen> createState() => _RemoteDashboardScreenState();
}

class _RemoteDashboardScreenState extends State<RemoteDashboardScreen> {
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _devices = [];
  Map<int, Map<String, dynamic>> _liveActivities = {};
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());

    final sync = context.read<SyncService>();
    sync.subscribeToChanges(() => _loadData());

    // Start polling for push notifications on phone side
    context.read<NotificationService>().startPolling();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    context.read<SyncService>().unsubscribe();
    context.read<NotificationService>().stopPolling();
    super.dispose();
  }

  Future<void> _loadData() async {
    final sync = context.read<SyncService>();
    final children = await sync.fetchChildren();
    final devices = await sync.fetchDevices();
    final liveActivities = await sync.fetchLiveActivities();
    if (mounted) {
      setState(() {
        _children = children;
        _devices = devices;
        _liveActivities = liveActivities;
        _isLoading = false;
      });
    }
  }

  void _signOut() async {
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Dashboard'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium),
            tooltip: 'Subscription',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
          PopupMenuButton<String>(
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'sign_out') _signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  auth.currentUser?.email ?? '',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
              if (auth.familyCode != null)
                PopupMenuItem(
                  enabled: false,
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        'Code: ${auth.familyCode}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      size: 16,
                      color: context.read<SubscriptionService>().isPremium
                          ? Colors.amber
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Plan: ${context.read<SubscriptionService>().planDisplayName}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'sign_out',
                child: Text('Sign Out', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: AppColors.backgroundDark,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildDevicesSection(),
                  const SizedBox(height: 20),
                  _buildChildrenSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildDevicesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.devices, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Linked Devices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_devices.isEmpty)
            const Text('No devices linked yet', style: TextStyle(color: AppColors.textMuted))
          else
            ..._devices.map((device) {
              final lastSeen = device['last_seen'] as String?;
              final isRecent = lastSeen != null &&
                  DateTime.now().difference(DateTime.parse(lastSeen)).inMinutes < 5;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      device['platform'] == 'tv' ? Icons.tv : Icons.phone_android,
                      size: 18,
                      color: isRecent ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        device['device_name'] ?? 'Unknown',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isRecent
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRecent ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isRecent ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildChildrenSection() {
    if (_children.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No child profiles yet.\nCreate profiles on your TV app.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Children',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ..._children.map((child) {
          final childLocalId = child['local_id'] as int;
          final liveActivity = _liveActivities[childLocalId];
          return _RemoteChildCard(
            child: child,
            liveActivity: liveActivity,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RemoteChildDetailScreen(child: child),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _RemoteChildCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final Map<String, dynamic>? liveActivity;
  final VoidCallback onTap;

  const _RemoteChildCard({required this.child, this.liveActivity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = child['name'] as String? ?? 'Unknown';
    final dailyLimit = child['daily_limit_minutes'] as int? ?? 0;
    final avatarColor = child['avatar_color'] as int? ?? 0xFF6C63FF;
    final isWatching = liveActivity != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isWatching ? AppColors.success.withValues(alpha: 0.5) : AppColors.cardBorder,
          width: isWatching ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(avatarColor),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isWatching)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isWatching) ...[
                      Row(
                        children: [
                          Icon(Icons.play_circle_filled, size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _liveActivityText(),
                              style: const TextStyle(fontSize: 13, color: AppColors.success),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'Daily limit: ${TimeUtils.formatMinutes(dailyLimit)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  String _liveActivityText() {
    if (liveActivity == null) return '';
    final appName = liveActivity!['app_name'] as String? ?? '';
    final mediaTitle = liveActivity!['media_title'] as String?;
    if (mediaTitle != null && mediaTitle.isNotEmpty) {
      return '$appName • $mediaTitle';
    }
    return 'Watching $appName';
  }
}
