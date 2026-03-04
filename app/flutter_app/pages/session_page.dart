import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/rowing_session.dart';

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
        setState(() {
          _connected = false;
          _status = 'Disconnected — tap retry';
        });
      }
    });

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        setState(() => _status = 'Connecting… (attempt $attempt/3)');
        await widget.device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
        );
        try { await widget.device.requestMtu(512); } catch (_) {}
        setState(() {
          _status = 'Connected. Discovering services…';
          _connected = true;
        });
        break;
      } catch (e) {
        if (attempt == 3) {
          setState(() => _status =
              'Failed to connect after 3 attempts.\nMake sure ESP32 is on.\nError: $e');
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
            if (c.characteristicUuid == Guid(kCmdCharUUID)) _cmdChar = c;
            if (c.characteristicUuid == Guid(kDataCharUUID)) _dataChar = c;
          }
        }
      }

      if (_cmdChar == null || _dataChar == null) {
        final found = services.map((s) => s.serviceUuid.toString()).join(', ');
        setState(() => _status = 'Characteristics not found.\nServices: $found');
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
      case pktMetadata:
        if (data.length >= 13) {
          _strokeCount = ByteData.sublistView(data, 3, 7).getUint32(0, Endian.little);
          _durationSec = ByteData.sublistView(data, 7, 11).getUint32(0, Endian.little);
          final splitTenths = ByteData.sublistView(data, 11, 13).getUint16(0, Endian.little);
          _avgSplit = splitTenths / 10.0;
          setState(() => _status = 'Receiving stroke data…');
        }
      case pktStrokes:
        final numTs = (data.length - 3) ~/ 4;
        for (int i = 0; i < numTs; i++) {
          _strokeTs.add(
            ByteData.sublistView(data, 3 + i * 4, 7 + i * 4).getUint32(0, Endian.little),
          );
        }
        setState(() => _status = 'Received ${_strokeTs.length} strokes…');
      case pktEnd:
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
          widget.device.platformName.isEmpty ? 'Gondolier' : widget.device.platformName,
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
              _StatRow('Timestamps received', '${_session!.strokeTimestampsMs.length}'),
              const SizedBox(height: 20),
              Text(
                'Stroke cadence chart (${_session!.strokeTimestampsMs.length} points)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_session!.strokeTimestampsMs.length > 1)
                SizedBox(
                  height: 150,
                  child: _CadenceChart(timestamps: _session!.strokeTimestampsMs),
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
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CadenceChart extends StatelessWidget {
  final List<int> timestamps;
  const _CadenceChart({required this.timestamps});

  @override
  Widget build(BuildContext context) {
    final intervals = <double>[];
    for (int i = 1; i < timestamps.length; i++) {
      intervals.add((timestamps[i] - timestamps[i - 1]) / 1000.0);
    }
    final maxI = intervals.fold(0.0, (a, b) => a > b ? a : b);
    if (maxI == 0) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: intervals.map((iv) {
        return Flexible(
          child: Tooltip(
            message: '${iv.toStringAsFixed(1)}s',
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              height: 130 * (iv / maxI),
              color: Colors.blue,
            ),
          ),
        );
      }).toList(),
    );
  }
}
