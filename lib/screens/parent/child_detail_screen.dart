import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_profile.dart';
import '../../models/usage_record.dart';
import '../../providers/children_provider.dart';
import '../../providers/timer_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';
import '../../widgets/premium_gate.dart';
import '../../widgets/tv_focusable.dart';
import 'add_child_screen.dart';
import 'app_blocking_screen.dart';

class ChildDetailScreen extends StatefulWidget {
  final int childId;

  const ChildDetailScreen({super.key, required this.childId});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  ChildProfile? _child;
  int _usedToday = 0;
  List<UsageRecord> _history = [];
  int _blockedAppCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ChildrenProvider>();
    final child = await provider.getChild(widget.childId);
    if (child == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final used = await provider.getUsedMinutesToday(widget.childId);
    final history = await provider.getRecentUsage(widget.childId);
    final blockedCount = await provider.getBlockedAppCount(widget.childId);
    if (mounted) {
      setState(() {
        _child = child;
        _usedToday = used;
        _history = history;
        _blockedAppCount = blockedCount;
      });
    }
  }

  void _showEditLimitDialog() {
    final controller = TextEditingController(
      text: _child?.dailyLimitMinutes.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Set Daily Limit',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Minutes per day',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.backgroundMid,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0 && _child != null) {
                await context.read<ChildrenProvider>().updateChild(
                  _child!.copyWith(dailyLimitMinutes: minutes),
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadData();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBonusTimeDialog() {
    final options = [
      ('15 minutes', 15),
      ('30 minutes', 30),
      ('45 minutes', 45),
      ('1 hour', 60),
    ];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Bonus Time',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        children: options.map((option) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              final timer = context.read<TimerProvider>();
              if (timer.activeChildId == widget.childId) {
                timer.addBonusTime(option.$2);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('+${option.$1} added!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No active session for this child'),
                  ),
                );
              }
            },
            child: Text(
              option.$1,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Profile',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this profile?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          FilledButton(
            onPressed: () async {
              await context.read<ChildrenProvider>().deleteChild(
                widget.childId,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_child == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.backgroundMid),
        backgroundColor: AppColors.backgroundDark,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final child = _child!;
    final remaining = (child.dailyLimitMinutes - _usedToday).clamp(
      0,
      child.dailyLimitMinutes,
    );
    final usageProgress = child.dailyLimitMinutes > 0
        ? (_usedToday / child.dailyLimitMinutes).clamp(0.0, 1.0)
        : 0.0;
    final allowedNow = child.isTodayAllowed && child.isWithinAllowedHours;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Profile'),
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddChildScreen(existingChild: child),
                ),
              );
              _loadData();
            },
          ),
        ],
      ),
      backgroundColor: AppColors.backgroundDark,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
        children: [
          _ProfileHero(
            child: child,
            allowedNow: allowedNow,
            blockedAppCount: _blockedAppCount,
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 700;
              final stats = [
                _StatTile(
                  icon: Icons.timer_outlined,
                  label: 'Daily Limit',
                  value: TimeUtils.formatMinutes(child.dailyLimitMinutes),
                  color: AppColors.primaryLight,
                  onPressed: _showEditLimitDialog,
                  autofocus: true,
                ),
                _StatTile(
                  icon: Icons.schedule_outlined,
                  label: 'Allowed Window',
                  value: child.allowedHoursString,
                  color: AppColors.accentLight,
                  onPressed: _showEditLimitDialog,
                ),
                _StatTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Active Days',
                  value: _allowedDayCount(child).toString(),
                  suffix: 'days',
                  color: AppColors.success,
                  onPressed: _showEditLimitDialog,
                ),
              ];

              return Column(
                children: [
                  twoColumns
                      ? Row(
                          children: [
                            for (var i = 0; i < stats.length; i++) ...[
                              Expanded(child: stats[i]),
                              if (i != stats.length - 1)
                                const SizedBox(width: 14),
                            ],
                          ],
                        )
                      : Column(
                          children: [
                            for (final stat in stats) ...[
                              stat,
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                  const SizedBox(height: 18),
                  twoColumns
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _UsagePanel(
                                usedToday: _usedToday,
                                remaining: remaining,
                                limit: child.dailyLimitMinutes,
                                progress: usageProgress,
                                childId: widget.childId,
                                onAddBonusTime: _showBonusTimeDialog,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 4,
                              child: _SchedulePanel(child: child),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _UsagePanel(
                              usedToday: _usedToday,
                              remaining: remaining,
                              limit: child.dailyLimitMinutes,
                              progress: usageProgress,
                              childId: widget.childId,
                              onAddBonusTime: _showBonusTimeDialog,
                            ),
                            const SizedBox(height: 18),
                            _SchedulePanel(child: child),
                          ],
                        ),
                  const SizedBox(height: 18),
                  twoColumns
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _AppBlockingPanel(
                                blockedAppCount: _blockedAppCount,
                                canUseAppBlocking: context
                                    .watch<ChildrenProvider>()
                                    .canUseAppBlocking,
                                onManageApps: () async {
                                  final provider = context
                                      .read<ChildrenProvider>();
                                  if (!provider.canUseAppBlocking) {
                                    showUpgradePrompt(context, 'App Blocking');
                                    return;
                                  }
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AppBlockingScreen(
                                        childId: widget.childId,
                                        childName: child.name,
                                      ),
                                    ),
                                  );
                                  _loadData();
                                },
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(child: _HistoryPanel(history: _history)),
                          ],
                        )
                      : Column(
                          children: [
                            _AppBlockingPanel(
                              blockedAppCount: _blockedAppCount,
                              canUseAppBlocking: context
                                  .watch<ChildrenProvider>()
                                  .canUseAppBlocking,
                              onManageApps: () async {
                                final provider = context
                                    .read<ChildrenProvider>();
                                if (!provider.canUseAppBlocking) {
                                  showUpgradePrompt(context, 'App Blocking');
                                  return;
                                }
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AppBlockingScreen(
                                      childId: widget.childId,
                                      childName: child.name,
                                    ),
                                  ),
                                );
                                _loadData();
                              },
                            ),
                            const SizedBox(height: 18),
                            _HistoryPanel(history: _history),
                          ],
                        ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _DeleteAction(onPressed: _showDeleteDialog),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  int _allowedDayCount(ChildProfile child) {
    return [
      child.mondayAllowed,
      child.tuesdayAllowed,
      child.wednesdayAllowed,
      child.thursdayAllowed,
      child.fridayAllowed,
      child.saturdayAllowed,
      child.sundayAllowed,
    ].where((allowed) => allowed).length;
  }
}

class _ProfileHero extends StatelessWidget {
  final ChildProfile child;
  final bool allowedNow;
  final int blockedAppCount;

  const _ProfileHero({
    required this.child,
    required this.allowedNow,
    required this.blockedAppCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF222646), Color(0xFF16172B)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Color(child.avatarColor),
            child: Text(
              child.name.isEmpty ? '?' : child.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      icon: allowedNow
                          ? Icons.check_circle_outline
                          : Icons.do_not_disturb_on_outlined,
                      label: allowedNow ? 'Allowed now' : 'Blocked now',
                      color: allowedNow ? AppColors.success : AppColors.warning,
                    ),
                    _StatusChip(
                      icon: Icons.block_outlined,
                      label:
                          '$blockedAppCount app${blockedAppCount == 1 ? '' : 's'} blocked',
                      color: blockedAppCount == 0
                          ? AppColors.textMuted
                          : AppColors.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.shield_outlined,
            color: AppColors.primaryLight,
            size: 36,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? suffix;
  final Color color;
  final VoidCallback onPressed;
  final bool autofocus;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onPressed,
    this.suffix,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(16),
      onPressed: onPressed,
      focusColor: AppColors.accent,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (suffix != null) ...[
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            suffix!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              Icon(icon, color: AppColors.primaryLight, size: 21),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _UsagePanel extends StatelessWidget {
  final int usedToday;
  final int remaining;
  final int limit;
  final double progress;
  final int childId;
  final VoidCallback onAddBonusTime;

  const _UsagePanel({
    required this.usedToday,
    required this.remaining,
    required this.limit,
    required this.progress,
    required this.childId,
    required this.onAddBonusTime,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = usedToday >= limit
        ? AppColors.error
        : AppColors.success;

    return _Panel(
      title: "Today's Usage",
      icon: Icons.donut_large_outlined,
      child: Row(
        children: [
          SizedBox(
            width: 138,
            height: 138,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 13,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.surfaceLight.withValues(alpha: 0.85),
                  ),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 13,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'used',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricBlock(
                        label: 'Used',
                        value: TimeUtils.formatMinutes(usedToday),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricBlock(
                        label: 'Remaining',
                        value: TimeUtils.formatMinutes(remaining),
                        valueColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                Consumer<TimerProvider>(
                  builder: (_, timer, __) {
                    if (timer.activeChildId == childId && timer.isRunning) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _InlineNotice(
                          icon: Icons.play_circle_outline,
                          text:
                              'Active: ${TimeUtils.formatCountdown(timer.remainingSeconds)}',
                          color: AppColors.accentLight,
                        ),
                      );
                    }
                    return const SizedBox(height: 12);
                  },
                ),
                _ActionTile(
                  icon: Icons.add_alarm_outlined,
                  label: 'Add Bonus Time',
                  detail: 'Give extra time for this session',
                  onPressed: onAddBonusTime,
                  focusColor: AppColors.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  final ChildProfile child;

  const _SchedulePanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Schedule',
      icon: Icons.event_available_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DayChip('Mon', child.mondayAllowed),
              _DayChip('Tue', child.tuesdayAllowed),
              _DayChip('Wed', child.wednesdayAllowed),
              _DayChip('Thu', child.thursdayAllowed),
              _DayChip('Fri', child.fridayAllowed),
              _DayChip('Sat', child.saturdayAllowed),
              _DayChip('Sun', child.sundayAllowed),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            child.allowedHoursString,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const _TimelineBar(),
          const SizedBox(height: 12),
          Row(
            children: const [
              _TimelineLabel('08:00', Alignment.centerLeft),
              _TimelineLabel('20:00', Alignment.centerRight),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  final bool active;

  const _DayChip(this.day, this.active);

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: active ? 0.44 : 0.18),
        ),
      ),
      child: Text(
        day,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? AppColors.textPrimary : AppColors.textMuted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            Expanded(flex: 1, child: Container(color: AppColors.surfaceLight)),
            Expanded(flex: 3, child: Container(color: AppColors.accentLight)),
            Expanded(flex: 1, child: Container(color: AppColors.surfaceLight)),
          ],
        ),
      ),
    );
  }
}

class _TimelineLabel extends StatelessWidget {
  final String label;
  final Alignment alignment;

  const _TimelineLabel(this.label, this.alignment);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: alignment,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}

class _AppBlockingPanel extends StatelessWidget {
  final int blockedAppCount;
  final bool canUseAppBlocking;
  final VoidCallback onManageApps;

  const _AppBlockingPanel({
    required this.blockedAppCount,
    required this.canUseAppBlocking,
    required this.onManageApps,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'App Blocking',
      icon: Icons.block_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InlineNotice(
            icon: blockedAppCount == 0
                ? Icons.check_circle_outline
                : Icons.do_not_disturb_on_outlined,
            text:
                '$blockedAppCount app${blockedAppCount == 1 ? '' : 's'} blocked',
            color: blockedAppCount == 0 ? AppColors.success : AppColors.error,
          ),
          const SizedBox(height: 14),
          _ActionTile(
            icon: Icons.apps_outlined,
            label: 'Manage Apps',
            detail: canUseAppBlocking
                ? 'Choose blocked apps'
                : 'Premium required',
            onPressed: onManageApps,
            trailing: canUseAppBlocking
                ? const Icon(Icons.chevron_right, color: AppColors.textMuted)
                : const PremiumBadge(),
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  final List<UsageRecord> history;

  const _HistoryPanel({required this.history});

  @override
  Widget build(BuildContext context) {
    final maxMinutes = history.fold<int>(
      1,
      (max, record) => record.usedMinutes > max ? record.usedMinutes : max,
    );

    return _Panel(
      title: 'Recent Usage',
      icon: Icons.bar_chart_outlined,
      child: history.isEmpty
          ? const SizedBox(
              height: 88,
              child: Center(
                child: Text(
                  'No usage recorded yet',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : Column(
              children: history.take(7).map((record) {
                final progress = (record.usedMinutes / maxMinutes).clamp(
                  0.06,
                  1.0,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(
                          record.date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 9,
                            backgroundColor: AppColors.surfaceLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 70,
                        child: Text(
                          TimeUtils.formatMinutes(record.usedMinutes),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onPressed;
  final Widget? trailing;
  final Color focusColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onPressed,
    this.trailing,
    this.focusColor = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(14),
      onPressed: onPressed,
      focusColor: focusColor,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DeleteAction extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeleteAction({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      borderRadius: BorderRadius.circular(12),
      focusColor: AppColors.error,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.26)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Text(
              'Delete Profile',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
