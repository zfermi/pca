import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_profile.dart';
import '../../models/usage_record.dart';
import '../../providers/children_provider.dart';
import '../../providers/timer_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';
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
    final controller = TextEditingController(text: _child?.dailyLimitMinutes.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set Daily Limit', style: TextStyle(color: AppColors.textPrimary)),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
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
    final options = [('15 minutes', 15), ('30 minutes', 30), ('45 minutes', 45), ('1 hour', 60)];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Bonus Time', style: TextStyle(color: AppColors.textPrimary)),
        children: options.map((option) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              final timer = context.read<TimerProvider>();
              if (timer.activeChildId == widget.childId) {
                timer.addBonusTime(option.$2);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('+${option.$1} added!'), backgroundColor: AppColors.success),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No active session for this child')),
                );
              }
            },
            child: Text(option.$1, style: const TextStyle(color: AppColors.textPrimary)),
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
        title: const Text('Delete Profile', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to delete this profile?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () async {
              await context.read<ChildrenProvider>().deleteChild(widget.childId);
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
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final child = _child!;
    final remaining = (child.dailyLimitMinutes - _usedToday).clamp(0, child.dailyLimitMinutes);

    return Scaffold(
      appBar: AppBar(
        title: Text(child.name),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddChildScreen(existingChild: child)),
              );
              _loadData();
            },
          ),
        ],
      ),
      backgroundColor: AppColors.backgroundDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _DetailCard(
              title: 'Settings',
              children: [
                _InfoRow('Daily Limit', TimeUtils.formatMinutes(child.dailyLimitMinutes)),
                _InfoRow('Allowed Hours', child.allowedHoursString),
                _InfoRow('Allowed Days', child.allowedDaysString),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _showEditLimitDialog,
                  child: const Text('Edit Limit', style: TextStyle(color: AppColors.primaryLight)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailCard(
              title: 'App Blocking',
              children: [
                Row(
                  children: [
                    const Icon(Icons.block, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$_blockedAppCount app${_blockedAppCount == 1 ? '' : 's'} blocked',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
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
                    icon: const Icon(Icons.apps),
                    label: const Text('Manage Blocked Apps'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailCard(
              title: "Today's Usage",
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: child.dailyLimitMinutes > 0 ? _usedToday / child.dailyLimitMinutes : 0,
                    minHeight: 10,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _usedToday >= child.dailyLimitMinutes ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow('Used Today', TimeUtils.formatMinutes(_usedToday)),
                _InfoRow('Remaining', TimeUtils.formatMinutes(remaining),
                    valueColor: AppColors.primary, bold: true),
                Consumer<TimerProvider>(
                  builder: (_, timer, __) {
                    if (timer.activeChildId == widget.childId && timer.isRunning) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Active: ${TimeUtils.formatCountdown(timer.remainingSeconds)}',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _showBonusTimeDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('Add Bonus Time'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailCard(
              title: 'Usage History (Last 7 Days)',
              children: [
                if (_history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No usage recorded yet', style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  ..._history.map((record) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(record.date, style: const TextStyle(color: AppColors.textPrimary))),
                        Text(TimeUtils.formatMinutes(record.usedMinutes),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(width: 16),
                        Text('${record.sessionCount} session(s)',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  )),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _showDeleteDialog,
              child: const Text('Delete Profile', style: TextStyle(color: AppColors.error, fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _InfoRow(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
