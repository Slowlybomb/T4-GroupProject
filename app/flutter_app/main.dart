// ─── Gondolier BLE Demo ───────────────────────────────────────────────────────
//
// Standalone prototype for testing BLE session download from the ESP32.
// The main app entry point is lib/main.dart.
//
// Dependencies (pubspec.yaml):
//   flutter_blue_plus: ^1.32.12
//   permission_handler: ^11.3.0
//
// Android permissions (AndroidManifest.xml):
//   BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION

import 'package:flutter/material.dart';

import 'pages/scan_page.dart';

void main() => runApp(const GondolierApp());

class GondolierApp extends StatelessWidget {
  const GondolierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gondolier BLE Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScanPage(),
    );
  }
}
