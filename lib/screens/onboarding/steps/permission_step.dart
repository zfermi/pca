import 'package:flutter/material.dart';
import '../../../services/platform_timer_service.dart';
import '../../../utils/app_colors.dart';

class PermissionStep extends StatefulWidget {
  final void Function(bool granted) onPermissionResult;

  const PermissionStep({super.key, required this.onPermissionResult});

  @override
  State<PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<PermissionStep>
    with WidgetsBindingObserver {
  bool _granted = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await PlatformTimerService.hasOverlayPermission();
    if (mounted) setState(() => _granted = granted);
  }

  Future<void> _requestPermission() async {
    setState(() => _checking = true);
    final granted = await PlatformTimerService.requestOverlayPermission();
    if (mounted) {
      setState(() {
        _granted = granted;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Row(
        children: [
          // Left — icon + explanation
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
                      colors: _granted
                          ? [AppColors.success, AppColors.success.withValues(alpha: 0.7)]
                          : [AppColors.accent, AppColors.accent.withValues(alpha: 0.7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_granted ? AppColors.success : AppColors.accent)
                            .withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _granted ? Icons.check_circle : Icons.layers,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Screen Overlay',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This lets the app display a lock screen\non top of other apps when TV time runs out.',
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
          // Right — steps or granted state
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: _granted ? _buildGrantedContent() : _buildRequestContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _ExplainRow(step: '1', text: 'Tap the button below to open settings'),
        const SizedBox(height: 16),
        const _ExplainRow(step: '2', text: 'Find "TV Parental Control" and toggle it ON'),
        const SizedBox(height: 16),
        const _ExplainRow(step: '3', text: 'Come back here — we\'ll detect it automatically'),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _checking ? null : _requestPermission,
            icon: const Icon(Icons.settings),
            label: Text(
              _checking ? 'Opening settings...' : 'Grant Permission',
              style: const TextStyle(fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => widget.onPermissionResult(false),
          child: const Text(
            'Skip for now',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildGrantedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 12),
              Text(
                'Permission granted!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'The app can now block the screen when time\nruns out, even over YouTube or other apps.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => widget.onPermissionResult(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _ExplainRow extends StatelessWidget {
  final String step;
  final String text;

  const _ExplainRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
          child: Center(
            child: Text(step,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}
