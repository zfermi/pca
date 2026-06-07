import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/child_profile.dart';
import '../../providers/children_provider.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/tv_focusable.dart';
import '../subscription/subscription_screen.dart';
import 'add_child_screen.dart';
import 'child_detail_screen.dart';
import 'device_protection_screen.dart';
import 'pin_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ChildrenProvider>().loadChildren();
  }

  Future<void> _addChild() async {
    final provider = context.read<ChildrenProvider>();
    if (!provider.canAddChild) {
      showUpgradePrompt(context, 'Unlimited Child Profiles');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddChildScreen()),
    );
  }

  Future<void> _openSubscription() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
  }

  Future<void> _openPinSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinScreen()),
    );
  }

  Future<void> _openDeviceProtection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeviceProtectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium),
            tooltip: 'Subscription',
            onPressed: _openSubscription,
          ),
          IconButton(
            icon: const Icon(Icons.pin_outlined),
            tooltip: 'Change PIN',
            onPressed: _openPinSettings,
          ),
        ],
      ),
      body: Consumer<ChildrenProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final children = provider.children;
          return RefreshIndicator(
            onRefresh: provider.loadChildren,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(40, 18, 40, 34),
              children: [
                _DashboardHero(
                  children: children,
                  planName: subscription.planDisplayName,
                  isPremium: subscription.isPremium,
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: _QuickActions(
                        onAddChild: _addChild,
                        onSubscription: _openSubscription,
                        onPinSettings: _openPinSettings,
                        onDeviceProtection: _openDeviceProtection,
                        canAddChild: provider.canAddChild,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: children.isEmpty
                          ? _EmptyChildrenPanel(onAddChild: _addChild)
                          : _ChildrenPanel(children: children),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final List<ChildProfile> children;
  final String planName;
  final bool isPremium;

  const _DashboardHero({
    required this.children,
    required this.planName,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final totalLimit = children.fold<int>(
      0,
      (sum, child) => sum + child.dailyLimitMinutes,
    );
    final blockedToday = children
        .where((child) => !child.isTodayAllowed)
        .length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF222646), Color(0xFF16172B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.family_restroom,
              color: AppColors.primaryLight,
              size: 36,
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Family Controls',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  children.isEmpty
                      ? 'Add a child profile to start managing TV time.'
                      : '${children.length} child profile${children.length == 1 ? '' : 's'} configured',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          _HeroStat(
            label: 'Profiles',
            value: children.length.toString(),
            icon: Icons.people_alt_outlined,
          ),
          const SizedBox(width: 12),
          _HeroStat(
            label: 'Daily Limit',
            value: TimeUtils.formatMinutes(totalLimit),
            icon: Icons.timer_outlined,
          ),
          const SizedBox(width: 12),
          _HeroStat(
            label: blockedToday == 0 ? 'Allowed' : 'Blocked Today',
            value: blockedToday == 0 ? 'Today' : blockedToday.toString(),
            icon: blockedToday == 0
                ? Icons.check_circle_outline
                : Icons.block_outlined,
          ),
          const SizedBox(width: 12),
          _PlanBadge(planName: planName, isPremium: isPremium),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String planName;
  final bool isPremium;

  const _PlanBadge({required this.planName, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPremium
            ? AppColors.warning.withValues(alpha: 0.14)
            : AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPremium
              ? AppColors.warning.withValues(alpha: 0.45)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.workspace_premium,
            color: isPremium ? AppColors.warning : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(height: 10),
          Text(
            planName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Plan',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onAddChild;
  final VoidCallback onSubscription;
  final VoidCallback onPinSettings;
  final VoidCallback onDeviceProtection;
  final bool canAddChild;

  const _QuickActions({
    required this.onAddChild,
    required this.onSubscription,
    required this.onPinSettings,
    required this.onDeviceProtection,
    required this.canAddChild,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelTitle(title: 'Actions', icon: Icons.bolt_outlined),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.person_add_alt_1,
          label: 'Add Child',
          detail: canAddChild ? 'Create profile' : 'Upgrade required',
          autofocus: true,
          onPressed: onAddChild,
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.workspace_premium,
          label: 'Subscription',
          detail: 'Plan and billing',
          onPressed: onSubscription,
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.pin_outlined,
          label: 'Change PIN',
          detail: 'Parent access',
          onPressed: onPinSettings,
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.admin_panel_settings_outlined,
          label: 'Protection',
          detail: 'Uninstall and kiosk',
          onPressed: onDeviceProtection,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool autofocus;
  final VoidCallback onPressed;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(14),
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ChildrenPanel extends StatelessWidget {
  final List<ChildProfile> children;

  const _ChildrenPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _PanelTitle(title: 'Children', icon: Icons.people_outline),
            const Spacer(),
            Text(
              '${children.length} total',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth > 760;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: children.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: twoColumns ? 2 : 1,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 158,
              ),
              itemBuilder: (context, index) =>
                  _ChildCard(child: children[index]),
            );
          },
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildProfile child;

  const _ChildCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final allowedNow = child.isTodayAllowed && child.isWithinAllowedHours;
    final statusColor = allowedNow ? AppColors.success : AppColors.warning;

    return TvFocusable(
      borderRadius: BorderRadius.circular(16),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChildDetailScreen(childId: child.id!),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(child.avatarColor),
                  child: Text(
                    child.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          child.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    allowedNow ? 'Allowed now' : 'Outside allowed time',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 1,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _MiniMeta(
                        icon: Icons.timer_outlined,
                        text: TimeUtils.formatMinutes(child.dailyLimitMinutes),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniMeta(
                          icon: Icons.schedule_outlined,
                          text: child.allowedHoursString,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChildrenPanel extends StatelessWidget {
  final VoidCallback onAddChild;

  const _EmptyChildrenPanel({required this.onAddChild});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(18),
      onPressed: onAddChild,
      child: Container(
        height: 280,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_alt_1,
              color: AppColors.primaryLight,
              size: 54,
            ),
            SizedBox(height: 16),
            Text(
              'Add your first child',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create a profile with limits, schedules, and app rules.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PanelTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryLight, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
