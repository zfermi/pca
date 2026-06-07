# TV Parental Control App

A Flutter-based parental control app for Android TV with a companion phone dashboard. Single APK detects whether it's running on a TV or phone and adapts its UI accordingly.

## Features

### TV Mode (Child Session)
- **Daily Time Limits** — Set per-child screen time with countdown timer and lock screen overlay
- **Schedule Control** — Restrict allowed hours and days of the week
- **Per-App Blocking** — Block specific apps per child using AccessibilityService
- **Multi-Child Profiles** — Manage multiple children with individual settings
- **Parent PIN Lock** — PIN-protected settings with security question recovery
- **D-pad Navigation** — Fully optimized for TV remote control

### Phone Mode (Parent Dashboard)
- **Remote Monitoring** — See what your child is watching in real time
- **Cloud Sync** — All settings, usage, and activity synced via Supabase
- **Live Activity Feed** — "Now Watching" status with app name and media title
- **Usage History** — Daily usage stats, session counts, and trend tracking
- **Push Notifications** — Real-time alerts for session start/end, time limits, blocked app attempts
- **Notification History** — Browse all past alerts in a dedicated screen
- **Device Status** — See which TVs are online/offline
- **Family Linking** — Connect TV and phone with a family code (XXXX-XXXX)
- **Subscription Management** — Upgrade to Premium via PayPal or M-Pesa

### Freemium Model
- **Free Tier** — 1 child profile, basic timer, schedule control
- **Premium** — Unlimited children, app blocking, remote monitoring, push notifications
- **Pricing** — $3.99/month or $29.99/year (KSH 300/mo or KSH 2,500/yr for Kenya)
- **Payments** — PayPal and M-Pesa (Safaricom STK push)

## Architecture

```
Single APK
├── TV Device → Onboarding → Home → Child Sessions
│   ├── TimerService (foreground service with overlay lock screen)
│   ├── AppBlockerService (AccessibilityService for per-app blocking)
│   └── ActivityTracker (foreground app + media session monitoring)
│
└── Phone Device → Login → Remote Dashboard
    ├── Live activity view per child
    ├── Usage stats and history
    ├── Push notification alerts (FCM)
    └── Blocked apps and schedule overview
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State Management | Provider + ChangeNotifier |
| Local Database | SQLite (sqflite) |
| Cloud Backend | Supabase (Auth, PostgreSQL, Realtime) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Native Services | Kotlin (AccessibilityService, WindowManager, MediaSessionManager) |
| Platform Bridge | MethodChannel |

## Project Structure

```
lib/
├── config/          # Supabase configuration
├── database/        # SQLite database helper and migrations
├── models/          # Data models (ChildProfile, InstalledApp, UsageRecord)
├── providers/       # State management (ChildrenProvider, TimerProvider)
├── screens/
│   ├── auth/        # Login screen (phone mode)
│   ├── onboarding/  # TV setup wizard (6 steps)
│   ├── parent/      # TV parent screens (child detail, app blocking)
│   ├── remote/      # Phone dashboard screens
│   └── home_screen.dart
├── services/
│   ├── auth_service.dart              # Supabase auth + family management
│   ├── sync_service.dart              # Cloud sync + realtime subscriptions
│   ├── activity_monitor_service.dart  # TV activity tracking → Supabase
│   ├── notification_service.dart      # FCM push notifications
│   ├── subscription_service.dart      # Freemium gating + payment management
│   └── platform_timer_service.dart    # Native platform channel bridge
├── utils/           # Colors, time formatting, PIN manager
└── main.dart        # Entry point, mode detection, provider setup

android/app/src/main/kotlin/.../
├── MainActivity.kt        # Platform channel handler
├── TimerService.kt        # Foreground timer with notification
├── OverlayLockScreen.kt   # Full-screen lock when time expires
├── AppBlockerService.kt   # AccessibilityService for app blocking
├── AppBlockerOverlay.kt   # Overlay shown on blocked apps
├── ActivityTracker.kt     # Foreground app + media session tracker
└── BootReceiver.kt        # Restart service on device boot
```

## Setup

### Prerequisites
- Flutter SDK 3.x
- Android Studio with Kotlin support
- A Supabase project

### 1. Clone and install
```bash
git clone https://github.com/zfermi/pca.git
cd pca
flutter pub get
```

### 2. Supabase setup
1. Create a Supabase project
2. Run the schema in `supabase_schema.sql` in the SQL Editor
3. Update `lib/config/supabase_config.dart` with your project URL and anon key

### 3. Firebase setup (for push notifications)
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app with package name `com.parentalcontrol.tv_parental_control`
3. Download `google-services.json` and place it in `android/app/`
4. Run `supabase_fcm_schema.sql` in the Supabase SQL Editor to create notification tables

### 4. Build and install
```bash
# Debug build
flutter build apk --debug

# Install on Android TV via ADB
adb connect <tv-ip>:5555
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

## Permissions

| Permission | Purpose |
|-----------|---------|
| `SYSTEM_ALERT_WINDOW` | Lock screen overlay when time expires |
| `FOREGROUND_SERVICE` | Timer runs in background |
| `BIND_ACCESSIBILITY_SERVICE` | Monitor and block foreground apps |
| `PACKAGE_USAGE_STATS` | App usage statistics |
| `INTERNET` | Cloud sync with Supabase |
| `RECEIVE_BOOT_COMPLETED` | Restart services after reboot |

## Supabase Schema

Tables: `families`, `devices`, `children`, `usage_records`, `blocked_apps`, `activity_logs`, `fcm_tokens`, `notification_queue`, `subscriptions`

All tables use Row Level Security (RLS) scoped to family membership. Realtime is enabled on `children`, `usage_records`, `activity_logs`, `blocked_apps`, and `notification_queue`.

## Roadmap

- [x] Phase 1: Per-app blocking (AccessibilityService + overlay)
- [x] Phase 2: Supabase integration (auth, sync, remote dashboard)
- [x] Phase 3: Remote monitoring (activity tracking + live parent view)
- [x] Phase 4: FCM push notifications (alerts on phone)
- [x] Phase 5: Freemium gating (PayPal + M-Pesa payments)

## License

Private project. All rights reserved.
