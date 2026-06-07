import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/platform_timer_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/tv_focusable.dart';

class DeviceProtectionScreen extends StatefulWidget {
  const DeviceProtectionScreen({super.key});

  @override
  State<DeviceProtectionScreen> createState() => _DeviceProtectionScreenState();
}

class _DeviceProtectionScreenState extends State<DeviceProtectionScreen> {
  Map<String, dynamic>? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await PlatformTimerService.getDeviceProtectionState();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _runPolicyAction(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _state = result;
    });
    final message = result['message'] as String?;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result['success'] == true
              ? AppColors.success
              : AppColors.error,
        ),
      );
    }
  }

  Future<void> _copyProvisioningCommand() async {
    final command = _state?['provisioningCommand'] as String? ?? '';
    if (command.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Provisioning command copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final supportsDeviceAdmin = state?['supportsDeviceAdmin'] == true;
    final isAdminActive = state?['isAdminActive'] == true;
    final isDeviceOwner = state?['isDeviceOwner'] == true;
    final uninstallBlocked = state?['uninstallBlocked'] == true;
    final appsControlRestricted = state?['appsControlRestricted'] == true;
    final lockTaskPermitted = state?['lockTaskPermitted'] == true;
    final fullyProtected =
        isDeviceOwner && uninstallBlocked && appsControlRestricted;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Device Protection'),
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: state == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(40, 18, 40, 34),
              children: [
                _ProtectionHero(fullyProtected: fullyProtected),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 760;
                    final status = _StatusPanel(
                      supportsDeviceAdmin: supportsDeviceAdmin,
                      isAdminActive: isAdminActive,
                      isDeviceOwner: isDeviceOwner,
                      uninstallBlocked: uninstallBlocked,
                      appsControlRestricted: appsControlRestricted,
                      lockTaskPermitted: lockTaskPermitted,
                    );
                    final actions = _ActionsPanel(
                      busy: _busy,
                      isDeviceOwner: isDeviceOwner,
                      fullyProtected: fullyProtected,
                      lockTaskPermitted: lockTaskPermitted,
                      onRequestAdmin: () => _runPolicyAction(
                        PlatformTimerService.requestDeviceAdmin,
                      ),
                      onEnable: () => _runPolicyAction(
                        () => PlatformTimerService.setDeviceProtectionEnabled(
                          true,
                        ),
                      ),
                      onDisable: () => _runPolicyAction(
                        () => PlatformTimerService.setDeviceProtectionEnabled(
                          false,
                        ),
                      ),
                      onStartKiosk: () =>
                          _runPolicyAction(PlatformTimerService.startKioskMode),
                      onStopKiosk: () =>
                          _runPolicyAction(PlatformTimerService.stopKioskMode),
                    );

                    if (!twoColumns) {
                      return Column(
                        children: [status, const SizedBox(height: 18), actions],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: status),
                        const SizedBox(width: 18),
                        Expanded(child: actions),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _ProvisioningPanel(
                  command: state['provisioningCommand'] as String? ?? '',
                  onCopy: _copyProvisioningCommand,
                ),
              ],
            ),
    );
  }
}

class _ProtectionHero extends StatelessWidget {
  final bool fullyProtected;

  const _ProtectionHero({required this.fullyProtected});

  @override
  Widget build(BuildContext context) {
    final color = fullyProtected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(24),
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
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Icon(
              fullyProtected
                  ? Icons.verified_user_outlined
                  : Icons.admin_panel_settings_outlined,
              color: color,
              size: 36,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullyProtected ? 'Protection Active' : 'Setup Required',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fullyProtected
                      ? 'Uninstall and app-control changes are blocked by Android policy.'
                      : 'Device Owner provisioning is required before Android can block uninstall or disable changes.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final bool supportsDeviceAdmin;
  final bool isAdminActive;
  final bool isDeviceOwner;
  final bool uninstallBlocked;
  final bool appsControlRestricted;
  final bool lockTaskPermitted;

  const _StatusPanel({
    required this.supportsDeviceAdmin,
    required this.isAdminActive,
    required this.isDeviceOwner,
    required this.uninstallBlocked,
    required this.appsControlRestricted,
    required this.lockTaskPermitted,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Android Policy Status',
      icon: Icons.fact_check_outlined,
      child: Column(
        children: [
          _StatusRow(
            label: 'Firmware Support',
            active: supportsDeviceAdmin,
            detail: supportsDeviceAdmin ? 'Supported' : 'Not advertised',
          ),
          _StatusRow(
            label: 'Device Admin',
            active: isAdminActive,
            detail: isAdminActive ? 'Active' : 'Not active',
          ),
          _StatusRow(
            label: 'Device Owner',
            active: isDeviceOwner,
            detail: isDeviceOwner ? 'Provisioned' : 'Not provisioned',
          ),
          _StatusRow(
            label: 'Uninstall Blocked',
            active: uninstallBlocked,
            detail: uninstallBlocked ? 'Blocked by OS' : 'User can uninstall',
          ),
          _StatusRow(
            label: 'App Controls',
            active: appsControlRestricted,
            detail: appsControlRestricted ? 'Restricted' : 'Can be changed',
          ),
          _StatusRow(
            label: 'Kiosk Allowlist',
            active: lockTaskPermitted,
            detail: lockTaskPermitted ? 'Ready' : 'Not allowlisted',
          ),
        ],
      ),
    );
  }
}

class _ActionsPanel extends StatelessWidget {
  final bool busy;
  final bool isDeviceOwner;
  final bool fullyProtected;
  final bool lockTaskPermitted;
  final VoidCallback onRequestAdmin;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onStartKiosk;
  final VoidCallback onStopKiosk;

  const _ActionsPanel({
    required this.busy,
    required this.isDeviceOwner,
    required this.fullyProtected,
    required this.lockTaskPermitted,
    required this.onRequestAdmin,
    required this.onEnable,
    required this.onDisable,
    required this.onStartKiosk,
    required this.onStopKiosk,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Parent Controls',
      icon: Icons.lock_outline,
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Activate Device Admin',
            detail: 'Fallback setup if supported',
            enabled: !busy,
            autofocus: true,
            onPressed: onRequestAdmin,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.shield_outlined,
            label: fullyProtected ? 'Refresh Protection' : 'Enable Protection',
            detail: isDeviceOwner
                ? 'Block uninstall and app controls'
                : 'Requires Device Owner first',
            enabled: !busy && isDeviceOwner,
            onPressed: onEnable,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.tv_outlined,
            label: 'Start Kiosk Mode',
            detail: lockTaskPermitted
                ? 'Lock TV into this app'
                : 'Enable protection first',
            enabled: !busy && lockTaskPermitted,
            onPressed: onStartKiosk,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.lock_open_outlined,
            label: 'Stop Kiosk Mode',
            detail: 'Parent PIN is required before this screen',
            enabled: !busy,
            onPressed: onStopKiosk,
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.remove_moderator_outlined,
            label: 'Disable Protection',
            detail: 'Allows uninstall and app changes',
            enabled: !busy && isDeviceOwner,
            danger: true,
            onPressed: onDisable,
          ),
        ],
      ),
    );
  }
}

class _ProvisioningPanel extends StatelessWidget {
  final String command;
  final VoidCallback onCopy;

  const _ProvisioningPanel({required this.command, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Provisioning',
      icon: Icons.terminal_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Run this after installing the app on a freshly provisionable TV:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: SelectableText(
              command,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.copy_outlined,
            label: 'Copy Command',
            detail: 'Use from the connected computer',
            onPressed: onCopy,
          ),
          const SizedBox(height: 12),
          const Text(
            'If Android rejects the command, remove accounts or factory reset the TV, install this app, then run it before regular setup.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
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

class _StatusRow extends StatelessWidget {
  final String label;
  final String detail;
  final bool active;

  const _StatusRow({
    required this.label,
    required this.detail,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onPressed;
  final bool enabled;
  final bool autofocus;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onPressed,
    this.enabled = true,
    this.autofocus = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.primaryLight;
    final content = Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: danger
                ? AppColors.error.withValues(alpha: 0.24)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: danger ? AppColors.error : AppColors.textPrimary,
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );

    if (!enabled) return content;

    return TvFocusable(
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(14),
      focusColor: danger ? AppColors.error : AppColors.accent,
      onPressed: onPressed,
      child: content,
    );
  }
}
