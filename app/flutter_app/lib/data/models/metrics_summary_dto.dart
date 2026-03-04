class MetricsSummaryDto {
  final DateTime from;
  final DateTime to;
  final int totalWorkouts;
  final double totalDistanceM;
  final int totalDurationSeconds;
  final int? avgSplit500mSeconds;
  final double? avgStrokeSpm;

  const MetricsSummaryDto({
    required this.from,
    required this.to,
    required this.totalWorkouts,
    required this.totalDistanceM,
    required this.totalDurationSeconds,
    required this.avgSplit500mSeconds,
    required this.avgStrokeSpm,
  });

  factory MetricsSummaryDto.fromJson(Map<String, dynamic> json) {
    final fromRaw = json['from']?.toString().trim() ?? '';
    final toRaw = json['to']?.toString().trim() ?? '';
    if (fromRaw.isEmpty || toRaw.isEmpty) {
      throw const FormatException('Metrics summary from/to are required');
    }

    return MetricsSummaryDto(
      from: DateTime.parse(fromRaw),
      to: DateTime.parse(toRaw),
      totalWorkouts: _intOrZero(json['total_workouts']),
      totalDistanceM: _doubleOrZero(json['total_distance_m']),
      totalDurationSeconds: _intOrZero(json['total_duration_seconds']),
      avgSplit500mSeconds: _intOrNull(json['avg_split_500m_seconds']),
      avgStrokeSpm: _doubleOrNull(json['avg_stroke_spm']),
    );
  }

  static int _intOrZero(Object? value) => _intOrNull(value) ?? 0;

  static int? _intOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  static double _doubleOrZero(Object? value) => _doubleOrNull(value) ?? 0.0;

  static double? _doubleOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}
