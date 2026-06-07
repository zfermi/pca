import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/pin_manager.dart';

class PinSetupStep extends StatefulWidget {
  final VoidCallback onPinSet;

  const PinSetupStep({super.key, required this.onPinSet});

  @override
  State<PinSetupStep> createState() => _PinSetupStepState();
}

class _PinSetupStepState extends State<PinSetupStep> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _answerController = TextEditingController();
  late final FocusNode _pinFocus;
  late final FocusNode _confirmFocus;
  late final FocusNode _questionFocus;
  late final FocusNode _answerFocus;
  late final FocusNode _buttonFocus;

  String? _pinError;
  String? _confirmError;
  String? _answerError;
  bool _obscurePin = true;
  bool _obscureConfirm = true;
  String _selectedQuestion = PinManager.securityQuestions[0];

  @override
  void initState() {
    super.initState();
    _pinFocus = FocusNode(
      debugLabel: 'PIN',
      onKeyEvent: (node, event) => _handlePinFieldKey(
        event,
        controller: _pinController,
        next: _confirmFocus,
        clearError: () => _pinError = null,
      ),
    );
    _confirmFocus = FocusNode(
      debugLabel: 'Confirm PIN',
      onKeyEvent: (node, event) => _handlePinFieldKey(
        event,
        controller: _confirmController,
        previous: _pinFocus,
        next: _questionFocus,
        clearError: () => _confirmError = null,
      ),
    );
    _questionFocus = FocusNode(
      debugLabel: 'Recovery Question',
      onKeyEvent: (node, event) =>
          _handleDpadKey(event, previous: _confirmFocus, next: _answerFocus),
    );
    _answerFocus = FocusNode(
      debugLabel: 'Recovery Answer',
      onKeyEvent: (node, event) =>
          _handleDpadKey(event, previous: _questionFocus, next: _buttonFocus),
    );
    _buttonFocus = FocusNode(
      debugLabel: 'Set PIN Button',
      onKeyEvent: (node, event) =>
          _handleDpadKey(event, previous: _answerFocus),
    );
    _pinFocus.addListener(() => _showKeyboardWhenFocused(_pinFocus));
    _confirmFocus.addListener(() => _showKeyboardWhenFocused(_confirmFocus));
    _answerFocus.addListener(() => _showKeyboardWhenFocused(_answerFocus));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusControl(_pinFocus);
    });
  }

  void _focusControl(FocusNode focusNode) {
    focusNode.requestFocus();
    _showKeyboardWhenFocused(focusNode);
  }

  void _showKeyboardWhenFocused(FocusNode focusNode) {
    if (!_isTextFieldFocus(focusNode)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !focusNode.hasFocus) return;
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  bool _isTextFieldFocus(FocusNode focusNode) {
    return focusNode == _pinFocus ||
        focusNode == _confirmFocus ||
        focusNode == _answerFocus;
  }

  KeyEventResult _handlePinFieldKey(
    KeyEvent event, {
    required TextEditingController controller,
    required VoidCallback clearError,
    FocusNode? previous,
    FocusNode? next,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final digit = _digitForKey(event);
    if (digit != null) {
      if (controller.text.length < 6) {
        setState(() {
          clearError();
          controller.text += digit;
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
        });
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      if (controller.text.isNotEmpty) {
        setState(() {
          controller.text = controller.text.substring(
            0,
            controller.text.length - 1,
          );
          controller.selection = TextSelection.collapsed(
            offset: controller.text.length,
          );
        });
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      if (next != null) _focusControl(next);
      return next == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }

    return _handleDpadKey(event, previous: previous, next: next);
  }

  String? _digitForKey(KeyDownEvent event) {
    final character = event.character;
    if (character != null && RegExp(r'^\d$').hasMatch(character)) {
      return character;
    }

    final digitKeys = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    return digitKeys[event.logicalKey];
  }

  KeyEventResult _handleDpadKey(
    KeyEvent event, {
    FocusNode? previous,
    FocusNode? next,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (next != null) _focusControl(next);
      return next == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (previous != null) _focusControl(previous);
      return previous == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _setPin() async {
    setState(() {
      _pinError = null;
      _confirmError = null;
      _answerError = null;
    });

    final pin = _pinController.text;
    final confirm = _confirmController.text;
    final answer = _answerController.text.trim();

    if (pin.length < 4) {
      setState(() => _pinError = 'PIN must be at least 4 digits');
      _focusControl(_pinFocus);
      return;
    }
    if (pin.length > 6) {
      setState(() => _pinError = 'PIN must be 6 digits or less');
      _focusControl(_pinFocus);
      return;
    }
    if (pin != confirm) {
      setState(() => _confirmError = 'PINs do not match');
      _focusControl(_confirmFocus);
      return;
    }
    if (answer.isEmpty) {
      setState(() => _answerError = 'Please provide an answer for recovery');
      _focusControl(_answerFocus);
      return;
    }

    await PinManager.setPin(pin);
    await PinManager.setSecurityQuestion(_selectedQuestion, answer);
    widget.onPinSet();
  }

  InputDecoration _inputDecoration(
    String label, {
    String? error,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: error,
      counterText: '',
      suffixIcon: suffix,
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      fillColor: AppColors.surface,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 560;
        final stepPadding = EdgeInsets.symmetric(
          horizontal: compact ? 36 : 48,
          vertical: compact ? 6 : 16,
        );
        final iconSize = compact ? 96.0 : 120.0;
        final iconGlyphSize = compact ? 44.0 : 52.0;
        final cardPadding = compact ? 16.0 : 28.0;
        final fieldGap = compact ? 8.0 : 16.0;
        final sectionGap = compact ? 10.0 : 24.0;

        return Padding(
          padding: stepPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
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
                            blurRadius: compact ? 22 : 30,
                            spreadRadius: compact ? 2 : 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock,
                        size: iconGlyphSize,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: compact ? 20 : 28),
                    Text(
                      'Create Parent PIN',
                      style: TextStyle(
                        fontSize: compact ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This PIN protects your settings so only\nyou can change time limits or unlock.',
                      style: TextStyle(
                        fontSize: compact ? 15 : 16,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 36 : 48),
              Expanded(
                flex: 5,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.all(cardPadding),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: TextField(
                              controller: _pinController,
                              focusNode: _pinFocus,
                              obscureText: _obscurePin,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                letterSpacing: 6,
                                color: AppColors.textPrimary,
                              ),
                              decoration: _inputDecoration(
                                'Enter PIN',
                                error: _pinError,
                                suffix: ExcludeFocus(
                                  child: IconButton(
                                    icon: Icon(
                                      _obscurePin
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePin = !_obscurePin,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _focusControl(_confirmFocus),
                            ),
                          ),
                          SizedBox(height: fieldGap),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(2),
                            child: TextField(
                              controller: _confirmController,
                              focusNode: _confirmFocus,
                              obscureText: _obscureConfirm,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                letterSpacing: 6,
                                color: AppColors.textPrimary,
                              ),
                              decoration: _inputDecoration(
                                'Confirm PIN',
                                error: _confirmError,
                                suffix: ExcludeFocus(
                                  child: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              onSubmitted: (_) => _questionFocus.requestFocus(),
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          Container(
                            padding: EdgeInsets.all(compact ? 14 : 16),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.help_outline,
                                      size: 18,
                                      color: AppColors.accentLight,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Recovery Question',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "In case you forget your PIN, you'll use this to reset it.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: compact ? 8 : 12),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(3),
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedQuestion,
                                    focusNode: _questionFocus,
                                    isExpanded: true,
                                    dropdownColor: AppColors.surfaceLight,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: _inputDecoration(''),
                                    items: PinManager.securityQuestions
                                        .map(
                                          (q) => DropdownMenuItem(
                                            value: q,
                                            child: Text(
                                              q,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedQuestion = v);
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(height: compact ? 8 : 12),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(4),
                                  child: TextField(
                                    controller: _answerController,
                                    focusNode: _answerFocus,
                                    textCapitalization: TextCapitalization.none,
                                    textInputAction: TextInputAction.done,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: _inputDecoration(
                                      'Your answer',
                                      error: _answerError,
                                    ),
                                    onChanged: (_) {
                                      setState(() => _answerError = null);
                                    },
                                    onSubmitted: (_) => _setPin(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: sectionGap),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(5),
                            child: SizedBox(
                              width: double.infinity,
                              height: compact ? 48 : 52,
                              child: FilledButton.icon(
                                focusNode: _buttonFocus,
                                onPressed: _setPin,
                                icon: const Icon(Icons.check),
                                label: const Text(
                                  'Set PIN & Continue',
                                  style: TextStyle(fontSize: 16),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _answerController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    _questionFocus.dispose();
    _answerFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }
}
