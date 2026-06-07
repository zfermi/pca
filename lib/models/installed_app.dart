import 'dart:typed_data';

class InstalledApp {
  final String packageName;
  final String appLabel;
  final Uint8List? icon;
  bool isBlocked;

  InstalledApp({
    required this.packageName,
    required this.appLabel,
    this.icon,
    this.isBlocked = false,
  });

  factory InstalledApp.fromMap(Map<String, dynamic> map) {
    return InstalledApp(
      packageName: map['packageName'] as String,
      appLabel: map['appLabel'] as String,
      icon: map['icon'] != null ? Uint8List.fromList(List<int>.from(map['icon'])) : null,
    );
  }
}
