import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── BLE UUIDs — must match networking.h ─────────────────────────────────────
const String kServiceUUID  = "12345678-1234-1234-1234-123456789abc";
const String kCmdCharUUID  = "12345678-1234-1234-1234-123456789ab0";
const String kDataCharUUID = "12345678-1234-1234-1234-123456789ab1";
const String kBleDeviceName = "Gondolier";

// ─── Packet types ─────────────────────────────────────────────────────────────
const int PKT_METADATA = 0x01;
const int PKT_STROKES  = 0x02;
const int PKT_END      = 0xFF;

// ─── Data model ──────────────────────────────────────────────────────────────
class RowingSession {
  final int strokeCount;
  final int durationSeconds;
  final double avgSplitSeconds;
  final List<int> strokeTimestampsMs;

  const RowingSession({
    required this.strokeCount,
    required this.durationSeconds,
    required this.avgSplitSeconds,
    required this.strokeTimestampsMs,
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

// ─── Scan Screen ─────────────────────────────────────────────────────────────
class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  final List<ScanResult> _results = [];
  bool _scanning = false;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _results.clear();
      _scanning = true;
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (final r in results) {
          if (r.device.platformName == kBleDeviceName &&
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
    if (mounted) setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Gondolier')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _scanning ? null : _startScan,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(_scanning ? 'Scanning…' : 'Scan again'),
            ),
          ),
          if (_scanning) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _scanning ? 'Looking for Gondolier device…' : 'No device found',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      return ListTile(
                        leading: const Icon(Icons.rowing),
                        title: Text(r.device.platformName),
                        subtitle: Text('RSSI: ${r.rssi} dBm'),
                        onTap: () {
                          FlutterBluePlus.stopScan();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BleSessionScreen(device: r.device),
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

// ─── Session Screen ───────────────────────────────────────────────────────────
class BleSessionScreen extends StatefulWidget {
  final BluetoothDevice device;
  const BleSessionScreen({super.key, required this.device});

  @override
  State<BleSessionScreen> createState() => _BleSessionScreenState();
}

class _BleSessionScreenState extends State<BleSessionScreen> {
  String _status = 'Connecting…';
  bool _connected = false;
  bool _receiving = false;
  RowingSession? _session;

  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _dataChar;
  StreamSubscription? _dataSub;
  StreamSubscription? _connSub;

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

    _connSub = widget.device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        if (mounted) setState(() { _connected = false; _status = 'Disconnected'; });
      }
    });

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        setState(() => _status = 'Connecting… ($attempt/3)');
        await widget.device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
        );
        try { await widget.device.requestMtu(512); } catch (_) {}
        setState(() { _status = 'Discovering services…'; _connected = true; });
        break;
      } catch (e) {
        if (attempt == 3) {
          setState(() => _status = 'Failed to connect: $e');
          return;
        }
        await Future.delayed(const Duration(seconds: 2));
        try { await widget.device.disconnect(); } catch (_) {}
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    try {
      final services = await widget.device.discoverServices();
      for (final svc in services) {
        if (svc.serviceUuid == Guid(kServiceUUID)) {
          for (final c in svc.characteristics) {
            if (c.characteristicUuid == Guid(kCmdCharUUID))  _cmdChar  = c;
            if (c.characteristicUuid == Guid(kDataCharUUID)) _dataChar = c;
          }
        }
      }

      if (_cmdChar == null || _dataChar == null) {
        setState(() => _status = 'Gondolier service not found on device.');
        return;
      }

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
        if (data.length >= 13) {
          _strokeCount = ByteData.sublistView(data, 3, 7).getUint32(0, Endian.little);
          _durationSec = ByteData.sublistView(data, 7, 11).getUint32(0, Endian.little);
          final splitTenths = ByteData.sublistView(data, 11, 13).getUint16(0, Endian.little);
          _avgSplit = splitTenths / 10.0;
          setState(() => _status = 'Receiving stroke data…');
        }
      case PKT_STROKES:
        final numTs = (data.length - 3) ~/ 4;
        for (int i = 0; i < numTs; i++) {
          _strokeTs.add(
            ByteData.sublistView(data, 3 + i * 4, 7 + i * 4).getUint32(0, Endian.little),
          );
        }
        setState(() => _status = 'Received ${_strokeTs.length} strokes…');
      case PKT_END:
        setState(() {
          _session = RowingSession(
            strokeCount: _strokeCount,
            durationSeconds: _durationSec,
            avgSplitSeconds: _avgSplit,
            strokeTimestampsMs: List.from(_strokeTs),
          );
          _receiving = false;
          _status = 'Transfer complete!';
        });
    }
  }

  Future<void> _requestSession() async {
    if (_cmdChar == null) return;
    setState(() { _receiving = true; _strokeTs.clear(); _status = 'Requesting session…'; });
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
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isEmpty ? 'Gondolier' : widget.device.platformName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              _connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: _connected ? Colors.green : Colors.red,
            ),
          ),
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
            const SizedBox(height: 16),
            if (!_connected)
              ElevatedButton.icon(
                onPressed: _connect,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
              ),
            ElevatedButton.icon(
              onPressed: (_connected && !_receiving) ? _requestSession : null,
              icon: const Icon(Icons.download),
              label: const Text('Get Session'),
            ),
            if (session != null) ...[
              const SizedBox(height: 24),
              const Text('Session Results',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              _StatRow('Strokes', '${session.strokeCount}'),
              _StatRow('Duration', session.formattedDuration),
              _StatRow('Avg Split (500 m)', session.formattedSplit),
              _StatRow('Timestamps', '${session.strokeTimestampsMs.length}'),
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
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
