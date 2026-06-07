import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/child_profile.dart';
import '../../providers/children_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/tv_focusable.dart';

class AddChildScreen extends StatefulWidget {
  final ChildProfile? existingChild;

  const AddChildScreen({super.key, this.existingChild});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _nameController = TextEditingController();
  int _selectedColorIndex = 0;
  double _dailyLimitMinutes = 120;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  final Map<int, bool> _daysAllowed = {
    DateTime.monday: true,
    DateTime.tuesday: true,
    DateTime.wednesday: true,
    DateTime.thursday: true,
    DateTime.friday: true,
    DateTime.saturday: true,
    DateTime.sunday: true,
  };
  String? _nameError;

  bool get _isEditing => widget.existingChild != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.existingChild!;
      _nameController.text = c.name;
      _selectedColorIndex = AppColors.avatarColors
          .indexWhere((color) => color.toARGB32() == c.avatarColor);
      if (_selectedColorIndex < 0) _selectedColorIndex = 0;
      _dailyLimitMinutes = c.dailyLimitMinutes.toDouble();
      _startTime = TimeOfDay(hour: c.allowedStartHour, minute: c.allowedStartMinute);
      _endTime = TimeOfDay(hour: c.allowedEndHour, minute: c.allowedEndMinute);
      _daysAllowed[DateTime.monday] = c.mondayAllowed;
      _daysAllowed[DateTime.tuesday] = c.tuesdayAllowed;
      _daysAllowed[DateTime.wednesday] = c.wednesdayAllowed;
      _daysAllowed[DateTime.thursday] = c.thursdayAllowed;
      _daysAllowed[DateTime.friday] = c.fridayAllowed;
      _daysAllowed[DateTime.saturday] = c.saturdayAllowed;
      _daysAllowed[DateTime.sunday] = c.sundayAllowed;
    }
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter a name');
      return;
    }

    final profile = ChildProfile(
      id: widget.existingChild?.id,
      name: name,
      avatarColor: AppColors.avatarColors[_selectedColorIndex].toARGB32(),
      dailyLimitMinutes: _dailyLimitMinutes.toInt(),
      mondayAllowed: _daysAllowed[DateTime.monday]!,
      tuesdayAllowed: _daysAllowed[DateTime.tuesday]!,
      wednesdayAllowed: _daysAllowed[DateTime.wednesday]!,
      thursdayAllowed: _daysAllowed[DateTime.thursday]!,
      fridayAllowed: _daysAllowed[DateTime.friday]!,
      saturdayAllowed: _daysAllowed[DateTime.saturday]!,
      sundayAllowed: _daysAllowed[DateTime.sunday]!,
      allowedStartHour: _startTime.hour,
      allowedStartMinute: _startTime.minute,
      allowedEndHour: _endTime.hour,
      allowedEndMinute: _endTime.minute,
    );

    final provider = context.read<ChildrenProvider>();
    if (_isEditing) {
      await provider.updateChild(profile);
    } else {
      await provider.addChild(profile);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Profile updated' : 'Profile saved'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  InputDecoration _inputDecoration(String hint, {String? error}) {
    return InputDecoration(
      hintText: hint,
      errorText: error,
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      errorStyle: const TextStyle(color: AppColors.error),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayValues = [
      DateTime.monday, DateTime.tuesday, DateTime.wednesday,
      DateTime.thursday, DateTime.friday, DateTime.saturday, DateTime.sunday,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Add Child Profile'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.backgroundDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Child Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              decoration: _inputDecoration('Enter name', error: _nameError),
              onChanged: (_) => setState(() => _nameError = null),
            ),

            const SizedBox(height: 24),
            const _SectionLabel('Avatar Color'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(AppColors.avatarColors.length, (index) {
                final isSelected = _selectedColorIndex == index;
                return TvFocusableCircle(
                  onPressed: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.avatarColors[index],
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: AppColors.avatarColors[index].withValues(alpha: 0.5),
                              blurRadius: 8, spreadRadius: 2,
                            )]
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),
            const _SectionLabel('Daily Time Limit'),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _formatLimit(_dailyLimitMinutes.toInt()),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceLight,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: _dailyLimitMinutes,
                min: 15,
                max: 480,
                divisions: 31,
                label: _formatLimit(_dailyLimitMinutes.toInt()),
                onChanged: (v) => setState(() => _dailyLimitMinutes = v),
              ),
            ),

            const SizedBox(height: 24),
            const _SectionLabel('Allowed Hours'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimePickerCard(
                    label: 'Start',
                    time: _startTime,
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _startTime);
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: _TimePickerCard(
                    label: 'End',
                    time: _endTime,
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _endTime);
                      if (picked != null) setState(() => _endTime = picked);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const _SectionLabel('Allowed Days'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final day = dayValues[index];
                final allowed = _daysAllowed[day]!;
                return FilterChip(
                  label: Text(dayLabels[index]),
                  selected: allowed,
                  onSelected: (v) => setState(() => _daysAllowed[day] = v),
                  selectedColor: AppColors.primary.withValues(alpha: 0.3),
                  checkmarkColor: AppColors.primaryLight,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: allowed ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                  side: BorderSide(
                    color: allowed ? AppColors.primary : AppColors.cardBorder,
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _isEditing ? 'Update Profile' : 'Save Profile',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatLimit(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _TimePickerCard extends StatefulWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerCard({required this.label, required this.time, required this.onTap});

  @override
  State<_TimePickerCard> createState() => _TimePickerCardState();
}

class _TimePickerCardState extends State<_TimePickerCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? AppColors.accent : AppColors.cardBorder,
          width: _focused ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _focused = f),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(widget.label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(
                widget.time.format(context),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
