import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/rowing_session.dart';
import 'session_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<ScanResult> _results = [];
  bool _scanning = false;
  bool _debugMode = false;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _startScan() async {
    setState(() {
      _results.clear();
      _scanning = true;
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (final r in results) {
          final name = r.device.platformName;
          final isTarget = name == bleDeviceName;
          final show = _debugMode ? name.isNotEmpty : isTarget;
          if (show && !_results.any((e) => e.device.remoteId == r.device.remoteId)) {
            _results.add(r);
          }
        }
      });
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      androidUsesFineLocation: false,
    );

    await Future.delayed(const Duration(seconds: 15));
    await FlutterBluePlus.stopScan();
    setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gondolier — Find Device')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(_scanning ? 'Scanning…' : 'Scan for Gondolier'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() => _debugMode = !_debugMode),
                child: Text(
                  _debugMode ? 'Show: All' : 'Show: Gondolier',
                  style: TextStyle(
                    fontSize: 12,
                    color: _debugMode ? Colors.orange : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final r = _results[i];
                final name = r.device.platformName.isEmpty
                    ? r.device.remoteId.toString()
                    : r.device.platformName;
                return ListTile(
                  leading: const Icon(Icons.rowing),
                  title: Text(name),
                  subtitle: Text('RSSI: ${r.rssi} dBm'),
                  onTap: () {
                    FlutterBluePlus.stopScan();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionPage(device: r.device),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
