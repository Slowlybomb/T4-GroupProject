// ─── BLE UUIDs — must match networking.h ─────────────────────────────────────
const String kServiceUUID  = "12345678-1234-1234-1234-123456789abc";
const String kCmdCharUUID  = "12345678-1234-1234-1234-123456789ab0";
const String kDataCharUUID = "12345678-1234-1234-1234-123456789ab1";
const String kStatCharUUID = "12345678-1234-1234-1234-123456789ab2";
const String bleDeviceName = "Gondolier";

// ─── Packet types ─────────────────────────────────────────────────────────────
const int pktMetadata = 0x01;
const int pktStrokes  = 0x02;
const int pktEnd      = 0xFF;

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
