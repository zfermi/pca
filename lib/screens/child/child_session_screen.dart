import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/child_profile.dart';
import '../../providers/children_provider.dart';
import '../../providers/timer_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/pin_manager.dart';
import '../../utils/time_utils.dart';
import 'lock_screen.dart';

class ChildSessionScreen extends StatefulWidget {
  const ChildSessionScreen({super.key});

  @override
  State<ChildSessionScreen> createState() => _ChildSessionScreenState();
}

class _ChildSessionScreenState extends State<ChildSessionScreen> {
  ChildProfile? _selectedChild;
  int _remainingMinutes = 0;
  String? _statusMessage;
  bool _canStart = false;

  @override
  void initState() {
    super.initState();
    context.read<ChildrenProvider>().loadChildren();
  }

  Future<void> _selectChild(ChildProfile child) async {
    final provider = context.read<ChildrenProvider>();
    final timer = context.read<TimerProvider>();

    if (timer.activeChildId == child.id && timer.isRunning) {
      setState(() => _selectedChild = child);
      _goToTimerView();
      return;
    }

    final remaining = await provider.getRemainingMinutesToday(child);

    setState(() {
      _selectedChild = child;
      _remainingMinutes = remaining;
    });

    if (!child.isTodayAllowed) {
      setState(() { _statusMessage = 'TV not allowed today'; _canStart = false; });
    } else if (!child.isWithinAllowedHours) {
      setState(() { _statusMessage = 'Outside allowed hours (${child.allowedHoursString})'; _canStart = false; });
    } else if (remaining <= 0) {
      setState(() { _statusMessage = 'Daily limit reached'; _canStart = false; });
    } else {
      setState(() { _statusMessage = null; _canStart = true; });
    }
  }

  void _startSession() async {
    if (_selectedChild == null || !_canStart) return;

    final child = _selectedChild!;
    final sessionMinutes = _remainingMinutes.clamp(0, child.minutesUntilEndOfAllowedTime);

    if (sessionMinutes <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No time available')),
      );
      return;
    }

    final pinHash = await PinManager.getStoredHash() ?? '';
    if (!mounted) return;

    final timer = context.read<TimerProvider>();
    timer.onTimeExpired = _onTimeExpired;
    timer.onFiveMinuteWarning = () => _showWarning('5 minutes remaining!');
    timer.onOneMinuteWarning = () => _showWarning('1 minute remaining!');
    await timer.startTimer(child: child, minutes: sessionMinutes, pinHash: pinHash);

    WakelockPlus.enable();
    if (!mounted) return;
    _goToTimerView();
  }

  void _goToTimerView() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _TimerView(childName: _selectedChild!.name),
      ),
    );
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onTimeExpired() {
    WakelockPlus.disable();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Profile'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: Consumer<ChildrenProvider>(
        builder: (context, provider, _) {
          if (provider.children.isEmpty) {
            return const Center(
              child: Text(
                'No profiles available.\nAsk a parent to create one.',
                style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  "Who's watching?",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: provider.children.length,
                  itemBuilder: (context, index) {
                    final child = provider.children[index];
                    final isSelected = _selectedChild?.id == child.id;
                    return _ProfileCard(
                      child: child,
                      isSelected: isSelected,
                      onTap: () => _selectChild(child),
                      autofocus: index == 0,
                    );
                  },
                ),
              ),
              if (_selectedChild != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _selectedChild!.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Remaining: ${TimeUtils.formatMinutes(_remainingMinutes)}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _statusMessage!,
                                style: const TextStyle(color: AppColors.error, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 200,
                        height: 52,
                        child: FilledButton(
                          onPressed: _canStart ? _startSession : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Start TV Time', style: TextStyle(fontSize: 17)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final ChildProfile child;
  final bool isSelected;
  final VoidCallback onTap;
  final bool autofocus;

  const _ProfileCard({
    required this.child,
    required this.isSelected,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: _focused
            ? const BorderSide(color: AppColors.accent, width: 3)
            : widget.isSelected
                ? const BorderSide(color: AppColors.primary, width: 3)
                : const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      elevation: widget.isSelected || _focused ? 8 : 2,
      shadowColor: _focused
          ? AppColors.accent.withValues(alpha: 0.3)
          : widget.isSelected
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.black26,
      child: InkWell(
        autofocus: widget.autofocus,
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Color(widget.child.avatarColor),
              child: Text(
                widget.child.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.child.name,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerView extends StatelessWidget {
  final String childName;

  const _TimerView({required this.childName});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Timer is running. Use parent PIN to stop.')),
          );
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1B2A), Color(0xFF1B2838)],
            ),
          ),
          child: SafeArea(
            child: Consumer<TimerProvider>(
              builder: (context, timer, _) {
                if (timer.timeExpired) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LockScreen()),
                    );
                  });
                  return const SizedBox.shrink();
                }

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        childName,
                        style: const TextStyle(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Time Remaining',
                        style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        TimeUtils.formatCountdown(timer.remainingSeconds),
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'monospace',
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: timer.progress,
                            minHeight: 10,
                            backgroundColor: AppColors.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              timer.remainingSeconds <= 300
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        timer.remainingSeconds <= 300
                            ? 'Almost done!'
                            : 'Enjoy your show!',
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
