import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/children_provider.dart';
import 'providers/timer_provider.dart';
import 'services/auth_service.dart';
import 'services/platform_timer_service.dart';
import 'services/activity_monitor_service.dart';
import 'services/sync_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/remote/remote_dashboard_screen.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool supabaseReady = false;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  final authService = AuthService(enabled: supabaseReady);
  if (supabaseReady) {
    await authService.initialize();
  }

  final syncService = SyncService(enabled: supabaseReady);
  if (supabaseReady && authService.familyId != null && authService.deviceId != null) {
    syncService.configure(
      familyId: authService.familyId!,
      deviceId: authService.deviceId!,
    );
  }

  final activityMonitor = ActivityMonitorService();
  activityMonitor.configure(syncService);

  runApp(TVPCAApp(
    authService: authService,
    syncService: syncService,
    activityMonitor: activityMonitor,
  ));
}

class TVPCAApp extends StatelessWidget {
  final AuthService authService;
  final SyncService syncService;
  final ActivityMonitorService activityMonitor;

  const TVPCAApp({
    super.key,
    required this.authService,
    required this.syncService,
    required this.activityMonitor,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChildrenProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: syncService),
        ChangeNotifierProvider.value(value: activityMonitor),
      ],
      child: MaterialApp(
        title: 'TV Parental Control',
        debugShowCheckedModeBanner: false,
        shortcuts: <ShortcutActivator, Intent>{
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.select):
              const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.gameButtonA):
              const ActivateIntent(),
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            error: AppColors.error,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(overlayColor: Colors.white24)
                .copyWith(
                  side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                    if (states.contains(WidgetState.focused)) {
                      return const BorderSide(
                        color: AppColors.accent,
                        width: 3,
                      );
                    }
                    return null;
                  }),
                ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom().copyWith(
              side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                if (states.contains(WidgetState.focused)) {
                  return const BorderSide(color: AppColors.accent, width: 3);
                }
                return const BorderSide(color: AppColors.primary, width: 2);
              }),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom().copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return AppColors.accent.withValues(alpha: 0.15);
                }
                return null;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return AppColors.accent.withValues(alpha: 0.1);
                }
                return null;
              }),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.accent, width: 2.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          chipTheme: ChipThemeData(
            side: WidgetStateBorderSide.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return const BorderSide(color: AppColors.accent, width: 2.5);
              }
              return null;
            }),
          ),
          sliderTheme: const SliderThemeData(
            thumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary,
          ),
          popupMenuTheme: PopupMenuThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          useMaterial3: true,
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool? _isTvDevice;
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final isTv = Platform.isAndroid
        ? await PlatformTimerService.isTvDevice()
        : false;
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('onboarding_complete') ?? false;

    // Wire sync service into children provider and activity monitor into timer
    if (mounted) {
      final sync = context.read<SyncService>();
      context.read<ChildrenProvider>().setSyncService(sync);
      context.read<TimerProvider>().setActivityMonitor(
        context.read<ActivityMonitorService>(),
      );

      // On TV, do a background sync if configured
      if (isTv && context.read<AuthService>().isLinkedToFamily) {
        sync.syncAll();
        context.read<AuthService>().updateDeviceLastSeen();
      }
    }

    if (mounted) {
      setState(() {
        _isTvDevice = isTv;
        _onboardingComplete = complete;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isTvDevice == null || _onboardingComplete == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Phone mode: show login or remote dashboard
    if (!_isTvDevice!) {
      final auth = context.watch<AuthService>();
      if (auth.isLoggedIn && auth.isLinkedToFamily) {
        return const RemoteDashboardScreen();
      }
      return const LoginScreen();
    }

    // TV mode: normal onboarding → home flow
    if (_onboardingComplete!) {
      return const HomeScreen();
    }

    return const OnboardingScreen();
  }
}

