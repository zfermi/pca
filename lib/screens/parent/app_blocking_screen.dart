import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/installed_app.dart';
import '../../providers/children_provider.dart';
import '../../services/platform_timer_service.dart';
import '../../utils/app_colors.dart';

class AppBlockingScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const AppBlockingScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<AppBlockingScreen> createState() => _AppBlockingScreenState();
}

class _AppBlockingScreenState extends State<AppBlockingScreen>
    with WidgetsBindingObserver {
  List<InstalledApp> _apps = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _accessibilityEnabled = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await PlatformTimerService.isAccessibilityEnabled();
    if (mounted) setState(() => _accessibilityEnabled = enabled);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = context.read<ChildrenProvider>();
    final apps = await provider.getInstalledApps(widget.childId);
    final enabled = await PlatformTimerService.isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        _apps = apps;
        _accessibilityEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBlockedApps() async {
    setState(() => _isSaving = true);
    await context.read<ChildrenProvider>().setBlockedApps(widget.childId, _apps);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blocked apps updated'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  List<InstalledApp> get _filteredApps {
    if (_searchQuery.isEmpty) return _apps;
    return _apps
        .where((a) => a.appLabel.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get _blockedCount => _apps.where((a) => a.isBlocked).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Blocking - ${widget.childName}'),
        backgroundColor: AppColors.backgroundMid,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveBlockedApps,
              tooltip: 'Save',
            ),
        ],
      ),
      backgroundColor: AppColors.backgroundDark,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                if (!_accessibilityEnabled) _buildAccessibilityBanner(),
                _buildHeader(),
                _buildSearchBar(),
                Expanded(child: _buildAppList()),
              ],
            ),
    );
  }

  Widget _buildAccessibilityBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accessibility Service required for app blocking to work. '
                  'Enable "TV Parental Control" in Accessibility settings.',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              autofocus: true,
              onPressed: () => PlatformTimerService.requestAccessibilityPermission(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Open Accessibility Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          const Icon(Icons.block, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Text(
            '$_blockedCount app${_blockedCount == 1 ? '' : 's'} blocked',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                for (final app in _apps) {
                  app.isBlocked = false;
                }
              });
            },
            child: const Text('Clear All', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search apps...',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.surface,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAppList() {
    final apps = _filteredApps;
    if (apps.isEmpty) {
      return const Center(
        child: Text('No apps found', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return _AppTile(
          app: app,
          autofocus: index == 0 && _accessibilityEnabled,
          onToggle: () {
            setState(() => app.isBlocked = !app.isBlocked);
          },
        );
      },
    );
  }
}

class _AppTile extends StatefulWidget {
  final InstalledApp app;
  final bool autofocus;
  final VoidCallback onToggle;

  const _AppTile({
    required this.app,
    required this.onToggle,
    this.autofocus = false,
  });

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _focused
            ? const BorderSide(color: AppColors.accent, width: 2)
            : const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      elevation: _focused ? 4 : 1,
      child: InkWell(
        autofocus: widget.autofocus,
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onToggle,
        onFocusChange: (f) => setState(() => _focused = f),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (widget.app.icon != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    widget.app.icon!,
                    width: 40,
                    height: 40,
                    errorBuilder: (_, __, ___) => _defaultIcon(),
                  ),
                )
              else
                _defaultIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.app.appLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.app.packageName,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.app.isBlocked,
                onChanged: (_) => widget.onToggle(),
                activeThumbColor: AppColors.error,
                activeTrackColor: AppColors.error.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.android, color: AppColors.textMuted, size: 24),
    );
  }
}
