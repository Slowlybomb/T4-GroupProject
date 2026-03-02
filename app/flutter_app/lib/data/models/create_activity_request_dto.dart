class CreateActivityRequestDto {
  final String? title;
  final String? notes;
  final DateTime startTime;
  final int? durationSeconds;
  final double? distanceM;
  final int? avgSplit500mSeconds;
  final int? avgStrokeSpm;
  final String visibility;
  final String? teamId;
  final Object? routeGeoJson;

  const CreateActivityRequestDto({
    this.title,
    this.notes,
    required this.startTime,
    this.durationSeconds,
    this.distanceM,
    this.avgSplit500mSeconds,
    this.avgStrokeSpm,
    required this.visibility,
    this.teamId,
    this.routeGeoJson,
  });

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'start_time': startTime.toUtc().toIso8601String(),
      'visibility': visibility,
    };

    if (_hasValue(title)) {
      payload['title'] = title!.trim();
    }
    if (_hasValue(notes)) {
      payload['notes'] = notes!.trim();
    }
    if (durationSeconds != null) {
      payload['duration_seconds'] = durationSeconds;
    }
    if (distanceM != null) {
      payload['distance_m'] = distanceM;
    }
    if (avgSplit500mSeconds != null) {
      payload['avg_split_500m_seconds'] = avgSplit500mSeconds;
    }
    if (avgStrokeSpm != null) {
      payload['avg_stroke_spm'] = avgStrokeSpm;
    }
    if (_hasValue(teamId)) {
      payload['team_id'] = teamId!.trim();
    }
    if (routeGeoJson != null) {
      payload['route_geojson'] = routeGeoJson;
    }

    return payload;
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
