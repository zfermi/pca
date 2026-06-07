import 'package:flutter_test/flutter_test.dart';
import 'package:tv_parental_control/main.dart';
import 'package:tv_parental_control/services/activity_monitor_service.dart';
import 'package:tv_parental_control/services/auth_service.dart';
import 'package:tv_parental_control/services/sync_service.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(TVPCAApp(
      authService: AuthService(enabled: false),
      syncService: SyncService(enabled: false),
      activityMonitor: ActivityMonitorService(),
    ));
  });
}
