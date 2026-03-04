// ─── Gondolier Flutter App — BLE Session Receiver ────────────────────────────
//
// Dependencies (pubspec.yaml):
//   flutter_blue_plus: ^1.32.12
//   permission_handler: ^11.3.0
//
// Add to AndroidManifest.xml (<manifest> level):
//   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
//   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── BLE UUIDs — must match networking.h ─────────────────────────────────────
const String kServiceUUID = "12345678-1234-1234-1234-123456789abc";
const String kCmdCharUUID = "12345678-1234-1234-1234-123456789ab0";
const String kDataCharUUID = "12345678-1234-1234-1234-123456789ab1";
const String kStatCharUUID = "12345678-1234-1234-1234-123456789ab2";
const String BLE_DEVICE_NAME = "Gondolier";

// ─── Packet types ─────────────────────────────────────────────────────────────
const int PKT_METADATA = 0x01;
const int PKT_STROKES = 0x02;
const int PKT_END = 0xFF;

// ─── Data model ──────────────────────────────────────────────────────────────
class RowingSession {
  int strokeCount;
  int durationSeconds;
  double avgSplitSeconds;
  List<int> strokeTimestampsMs;

  RowingSession({
    this.strokeCount = 0,
    this.durationSeconds = 0,
    this.avgSplitSeconds = 0,
    this.strokeTimestampsMs = const [],
  });

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String get formattedSplit {
    final total = avgSplitSeconds.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─── Entry point ─────────────────────────────────────────────────────────────
void main() => runApp(const GondolierApp());

class GondolierApp extends StatelessWidget {
  const GondolierApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gondolier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScanPage(),
    );
  }
}

// ─── Scan Page ────────────────────────────────────────────────────────────────
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final List<ScanResult> _results = [];
  bool _scanning = false;
  bool _debugMode = false; // set to true to show ALL nearby BLE devices
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
        for (var r in results) {
          final name = r.device.platformName;
          final isTarget = name == BLE_DEVICE_NAME;
          final show = _debugMode ? name.isNotEmpty : isTarget;
          if (show &&
              !_results.any((e) => e.device.remoteId == r.device.remoteId)) {
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

// ─── Session Page ─────────────────────────────────────────────────────────────
class SessionPage extends StatefulWidget {
  final BluetoothDevice device;
  const SessionPage({super.key, required this.device});
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  String _status = 'Connecting…';
  bool _connected = false;
  bool _receiving = false;
  bool _done = false;
  RowingSession? _session;

  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _dataChar;
  StreamSubscription? _dataSub;
  StreamSubscription? _connSub;

  // Partial session assembly
  int _strokeCount = 0;
  int _durationSec = 0;
  double _avgSplit = 0;
  final List<int> _strokeTs = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    setState(() => _status = 'Connecting…');

    // Listen to connection state BEFORE calling connect()
    _connSub = widget.device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        setState(() {
          _connected = false;
          _status = 'Disconnected — tap retry';
        });
      }
    });

    // Try up to 3 times — Android BLE can silently fail on first attempt
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        setState(() => _status = 'Connecting… (attempt $attempt/3)');

        await widget.device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect:
              false, // autoConnect=true causes the 15s timeout on Android
        );

        // Request higher MTU so packets aren't fragmented
        try {
          await widget.device.requestMtu(512);
        } catch (_) {
          // MTU negotiation failure is non-fatal; we'll use default
        }

        setState(() {
          _status = 'Connected. Discovering services…';
          _connected = true;
        });
        break; // success — exit retry loop
      } catch (e) {
        if (attempt == 3) {
          setState(
            () => _status =
                'Failed to connect after 3 attempts.\nMake sure ESP32 is on and not already connected.\nError: $e',
          );
          return;
        }
        // Short pause then retry
        await Future.delayed(const Duration(seconds: 2));
        try {
          await widget.device.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // Discover services
    try {
      final services = await widget.device.discoverServices();
      for (var svc in services) {
        if (svc.serviceUuid == Guid(kServiceUUID)) {
          for (var c in svc.characteristics) {
            if (c.characteristicUuid == Guid(kCmdCharUUID)) _cmdChar = c;
            if (c.characteristicUuid == Guid(kDataCharUUID)) _dataChar = c;
          }
        }
      }

      if (_cmdChar == null || _dataChar == null) {
        // Dump what we found to help debug
        final found = services.map((s) => s.serviceUuid.toString()).join(', ');
        setState(
          () => _status = 'Characteristics not found.\nServices seen: $found',
        );
        return;
      }

      // Subscribe to data notifications
      await _dataChar!.setNotifyValue(true);
      _dataSub = _dataChar!.lastValueStream.listen(_onData);

      setState(() => _status = 'Ready — tap "Get Session" to download');
    } catch (e) {
      setState(() => _status = 'Service discovery error: $e');
    }
  }

  void _onData(List<int> raw) {
    if (raw.isEmpty) return;
    final data = Uint8List.fromList(raw);

    switch (data[0]) {
      case PKT_METADATA:
        // [0x01][seq 2B][strokeCount 4B][durationSec 4B][splitTenths 2B]
        if (data.length >= 13) {
          _strokeCount = ByteData.sublistView(
            data,
            3,
            7,
          ).getUint32(0, Endian.little);
          _durationSec = ByteData.sublistView(
            data,
            7,
            11,
          ).getUint32(0, Endian.little);
          final splitTenths = ByteData.sublistView(
            data,
            11,
            13,
          ).getUint16(0, Endian.little);
          _avgSplit = splitTenths / 10.0;
          setState(() => _status = 'Receiving stroke data…');
        }
        break;

      case PKT_STROKES:
        // [0x02][seq 2B][ts0 4B][ts1 4B]…
        final numTs = (data.length - 3) ~/ 4;
        for (int i = 0; i < numTs; i++) {
          final ts = ByteData.sublistView(
            data,
            3 + i * 4,
            7 + i * 4,
          ).getUint32(0, Endian.little);
          _strokeTs.add(ts);
        }
        setState(() => _status = 'Received ${_strokeTs.length} strokes…');
        break;

      case PKT_END:
        _session = RowingSession(
          strokeCount: _strokeCount,
          durationSeconds: _durationSec,
          avgSplitSeconds: _avgSplit,
          strokeTimestampsMs: List.from(_strokeTs),
        );
        setState(() {
          _done = true;
          _receiving = false;
          _status = 'Transfer complete!';
        });
        break;
    }
  }

  Future<void> _requestSession() async {
    if (_cmdChar == null) return;
    setState(() {
      _receiving = true;
      _done = false;
      _strokeTs.clear();
      _status = 'Requesting session…';
    });
    await _cmdChar!.write('GET_SESSION'.codeUnits, withoutResponse: false);
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _connSub?.cancel();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.device.platformName.isEmpty
              ? 'Gondolier'
              : widget.device.platformName,
        ),
        actions: [
          Icon(
            _connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: _connected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            if (!_connected)
              ElevatedButton.icon(
                onPressed: _connect,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ElevatedButton.icon(
              onPressed: (_connected && !_receiving) ? _requestSession : null,
              icon: const Icon(Icons.download),
              label: const Text('Get Session'),
            ),
            const SizedBox(height: 30),
            if (_done && _session != null) ...[
              const Text(
                'Session Results',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _StatRow('Strokes', '${_session!.strokeCount}'),
              _StatRow('Duration', _session!.formattedDuration),
              _StatRow('Avg Split (500m)', _session!.formattedSplit),
              _StatRow(
                'Timestamps received',
                '${_session!.strokeTimestampsMs.length}',
              ),
              const SizedBox(height: 20),
              Text(
                'Stroke cadence chart (${_session!.strokeTimestampsMs.length} points)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_session!.strokeTimestampsMs.length > 1)
                SizedBox(
                  height: 150,
                  child: _CadenceChart(
                    timestamps: _session!.strokeTimestampsMs,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// Simple bar chart showing inter-stroke intervals
class _CadenceChart extends StatelessWidget {
  final List<int> timestamps;
  const _CadenceChart({required this.timestamps});

  @override
  Widget build(BuildContext context) {
    final intervals = <double>[];
    for (int i = 1; i < timestamps.length; i++) {
      intervals.add((timestamps[i] - timestamps[i - 1]) / 1000.0); // seconds
    }
    final maxI = intervals.fold(0.0, (a, b) => a > b ? a : b);
    if (maxI == 0) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: intervals.map((iv) {
        final frac = iv / maxI;
        return Flexible(
          child: Tooltip(
            message: '${iv.toStringAsFixed(1)}s',
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              height: 130 * frac,
              color: Colors.blue,
            ),
          ),
        );
      }).toList(),
    );
  }
}
