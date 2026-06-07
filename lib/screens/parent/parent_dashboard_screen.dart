import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_profile.dart';
import '../../providers/children_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';
import 'add_child_screen.dart';
import 'child_detail_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            color: AppColors.surface,
            onSelected: (value) {
              if (value == 'change_pin') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PinScreen()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'change_pin',
                child: Text('Change PIN', style: TextStyle(color: AppColors.textPrimary)),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: AppColors.backgroundDark,
      body: Consumer<ChildrenProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (provider.children.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'No child profiles yet.\nTap + to add one.',
                    style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: provider.children.length,
            itemBuilder: (context, index) {
              return _ChildCard(
                child: provider.children[index],
                autofocus: index == 0,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddChildScreen()));
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ChildCard extends StatefulWidget {
  final ChildProfile child;
  final bool autofocus;

  const _ChildCard({required this.child, this.autofocus = false});

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: _focused
            ? const BorderSide(color: AppColors.accent, width: 3)
            : const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      elevation: _focused ? 8 : 2,
      shadowColor: _focused ? AppColors.accent.withValues(alpha: 0.3) : Colors.black26,
      child: InkWell(
        autofocus: widget.autofocus,
        borderRadius: BorderRadius.circular(16),
        onFocusChange: (focused) => setState(() => _focused = focused),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChildDetailScreen(childId: widget.child.id!),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Color(widget.child.avatarColor),
                child: Text(
                  widget.child.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
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
                      widget.child.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily limit: ${TimeUtils.formatMinutes(widget.child.dailyLimitMinutes)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    Text(
                      'Allowed: ${widget.child.allowedHoursString}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
}
