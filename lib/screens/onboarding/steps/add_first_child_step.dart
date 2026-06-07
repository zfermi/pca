import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/child_profile.dart';
import '../../../providers/children_provider.dart';
import '../../../utils/app_colors.dart';

class AddFirstChildStep extends StatefulWidget {
  final VoidCallback onChildAdded;
  final VoidCallback onSkip;

  const AddFirstChildStep({
    super.key,
    required this.onChildAdded,
    required this.onSkip,
  });

  @override
  State<AddFirstChildStep> createState() => _AddFirstChildStepState();
}

class _AddFirstChildStepState extends State<AddFirstChildStep> {
  final _nameController = TextEditingController();
  late final FocusNode _nameFocus;
  late final List<FocusNode> _colorFocusNodes;
  late final FocusNode _sliderFocus;
  late final FocusNode _addButtonFocus;
  late final FocusNode _skipFocus;
  int _selectedColorIndex = 0;
  double _dailyLimit = 120;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameFocus = FocusNode(
      debugLabel: 'Child Name',
      onKeyEvent: (node, event) => _handleNameKey(event),
    );
    _colorFocusNodes = List.generate(
      AppColors.avatarColors.length,
      (index) => FocusNode(
        debugLabel: 'Avatar Color $index',
        onKeyEvent: (node, event) => _handleColorKey(event, index),
      ),
    );
    _sliderFocus = FocusNode(
      debugLabel: 'Daily Limit Slider',
      onKeyEvent: (node, event) => _handleSliderKey(event),
    );
    _addButtonFocus = FocusNode(
      debugLabel: 'Add Child Button',
      onKeyEvent: (node, event) =>
          _handleButtonKey(event, previous: _sliderFocus, next: _skipFocus),
    );
    _skipFocus = FocusNode(
      debugLabel: 'Skip Add Child',
      onKeyEvent: (node, event) =>
          _handleButtonKey(event, previous: _addButtonFocus),
    );
    for (final focusNode in [
      _nameFocus,
      ..._colorFocusNodes,
      _sliderFocus,
      _addButtonFocus,
      _skipFocus,
    ]) {
      focusNode.addListener(_rebuildForFocusChange);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusControl(_colorFocusNodes[_selectedColorIndex]);
    });
  }

  void _rebuildForFocusChange() {
    if (mounted) setState(() {});
  }

  void _focusControl(FocusNode focusNode) {
    focusNode.requestFocus();
  }

  void _showKeyboardForNameField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_nameFocus.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  KeyEventResult _handleNameKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusControl(_colorFocusNodes[_selectedColorIndex]);
      return KeyEventResult.handled;
    }

    if (_isSelectKey(event.logicalKey)) {
      _showKeyboardForNameField();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleColorKey(KeyEvent event, int index) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index > 0) {
      _selectColor(index - 1, moveFocus: true);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        index < _colorFocusNodes.length - 1) {
      _selectColor(index + 1, moveFocus: true);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusControl(_nameFocus);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusControl(_sliderFocus);
      return KeyEventResult.handled;
    }

    if (_isSelectKey(event.logicalKey)) {
      _selectColor(index);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSliderKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _adjustDailyLimit(-15);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _adjustDailyLimit(15);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusControl(_colorFocusNodes[_selectedColorIndex]);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusControl(_addButtonFocus);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleButtonKey(
    KeyEvent event, {
    FocusNode? previous,
    FocusNode? next,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (previous != null) _focusControl(previous);
      return previous == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (next != null) _focusControl(next);
      return next == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }

    if (_isSelectKey(event.logicalKey)) {
      if (_skipFocus.hasFocus) {
        widget.onSkip();
      } else if (!_saving) {
        _save();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  void _selectColor(int index, {bool moveFocus = false}) {
    setState(() => _selectedColorIndex = index);
    if (moveFocus) _focusControl(_colorFocusNodes[index]);
  }

  void _adjustDailyLimit(double delta) {
    setState(() {
      _dailyLimit = (_dailyLimit + delta).clamp(15, 480);
    });
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Enter your child\'s name');
      _focusControl(_nameFocus);
      _showKeyboardForNameField();
      return;
    }

    setState(() => _saving = true);

    final profile = ChildProfile(
      name: name,
      avatarColor: AppColors.avatarColors[_selectedColorIndex].toARGB32(),
      dailyLimitMinutes: _dailyLimit.toInt(),
    );

    await context.read<ChildrenProvider>().addChild(profile);

    if (mounted) widget.onChildAdded();
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    String? error,
    Widget? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      prefixIcon: prefix,
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left — icon + description
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.child_care,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Add Your First Child',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can add more children and customize\ntheir schedules later in the dashboard.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
          // Right — form
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      decoration: _inputDecoration(
                        "Child's name",
                        hint: 'e.g. Sarah',
                        error: _nameError,
                        prefix: const Icon(
                          Icons.person,
                          color: AppColors.textMuted,
                        ),
                      ),
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pick a color',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(AppColors.avatarColors.length, (
                        index,
                      ) {
                        final isSelected = _selectedColorIndex == index;
                        return Focus(
                          focusNode: _colorFocusNodes[index],
                          child: GestureDetector(
                            onTap: () => _selectColor(index, moveFocus: true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: isSelected ? 52 : 44,
                              height: isSelected ? 52 : 44,
                              decoration: BoxDecoration(
                                color: AppColors.avatarColors[index],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _colorFocusNodes[index].hasFocus
                                      ? AppColors.accentLight
                                      : isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: _colorFocusNodes[index].hasFocus
                                      ? 4
                                      : 3,
                                ),
                                boxShadow:
                                    isSelected ||
                                        _colorFocusNodes[index].hasFocus
                                    ? [
                                        BoxShadow(
                                          color: AppColors.avatarColors[index]
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Daily TV time limit',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatLimit(_dailyLimit.toInt()),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Focus(
                      focusNode: _sliderFocus,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _sliderFocus.hasFocus
                                ? AppColors.accentLight
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.surfaceLight,
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          child: Slider(
                            value: _dailyLimit,
                            min: 15,
                            max: 480,
                            divisions: 31,
                            label: _formatLimit(_dailyLimit.toInt()),
                            onChanged: (v) => setState(() => _dailyLimit = v),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '15m',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '8h',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        focusNode: _addButtonFocus,
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          _saving ? 'Saving...' : 'Add Child & Continue',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      focusNode: _skipFocus,
                      onPressed: widget.onSkip,
                      child: const Text(
                        "I'll do this later",
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    _nameFocus.dispose();
    for (final focusNode in _colorFocusNodes) {
      focusNode.dispose();
    }
    _sliderFocus.dispose();
    _addButtonFocus.dispose();
    _skipFocus.dispose();
    super.dispose();
  }
}
