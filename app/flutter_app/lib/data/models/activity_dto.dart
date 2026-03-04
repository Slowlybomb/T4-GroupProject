import 'activity_model.dart';

class ActivityDto {
  final String id;
  final String userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
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
  final int likes;
  final int comments;
  final DateTime createdAt;

  const ActivityDto({
    required this.id,
    required this.userId,
    this.username,
    this.displayName,
    this.avatarUrl,
    required this.title,
    required this.notes,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceM,
    required this.avgSplit500mSeconds,
    required this.avgStrokeSpm,
    required this.visibility,
    required this.teamId,
    required this.routeGeoJson,
    required this.likes,
    required this.comments,
    required this.createdAt,
  });

  factory ActivityDto.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final userId = json['user_id']?.toString().trim() ?? '';
    final startTimeRaw = json['start_time']?.toString().trim() ?? '';
    final createdAtRaw = json['created_at']?.toString().trim() ?? '';
    final visibility = json['visibility']?.toString().trim() ?? '';

    if (id.isEmpty) {
      throw const FormatException('Activity id is missing');
    }
    if (userId.isEmpty) {
      throw const FormatException('Activity user_id is missing');
    }
    if (startTimeRaw.isEmpty) {
      throw const FormatException('Activity start_time is missing');
    }
    if (createdAtRaw.isEmpty) {
      throw const FormatException('Activity created_at is missing');
    }
    if (visibility.isEmpty) {
      throw const FormatException('Activity visibility is missing');
    }

    return ActivityDto(
      id: id,
      userId: userId,
      username: _stringOrNull(json['username']),
      displayName: _stringOrNull(json['display_name']),
      avatarUrl: _normalizeAvatarUrl(_stringOrNull(json['avatar_url'])),
      title: _stringOrNull(json['title']),
      notes: _stringOrNull(json['notes']),
      startTime: DateTime.parse(startTimeRaw),
      durationSeconds: _intOrNull(json['duration_seconds']),
      distanceM: _doubleOrNull(json['distance_m']),
      avgSplit500mSeconds: _intOrNull(json['avg_split_500m_seconds']),
      avgStrokeSpm: _intOrNull(json['avg_stroke_spm']),
      visibility: visibility,
      teamId: _stringOrNull(json['team_id']),
      routeGeoJson: json['route_geojson'],
      likes: _intOrZero(json['likes']),
      comments: _intOrZero(json['comments']),
      createdAt: DateTime.parse(createdAtRaw),
    );
  }

  ActivityModel toActivityModel() {
    // Adapter layer: keep existing UI model stable while backend schema evolves.
    return ActivityModel(
      id: id,
      userId: userId,
      userName: _resolveDisplayName(
        displayName: displayName,
        username: username,
        userId: userId,
      ),
      avatarUrl: avatarUrl,
      timestamp: _formatTimestamp(startTime),
      title: title?.trim().isNotEmpty == true
          ? title!.trim()
          : 'Untitled activity',
      distance: _formatDistance(distanceM),
      duration: _formatDuration(durationSeconds),
      avgSplit: _formatAvgSplit(avgSplit500mSeconds),
      strokeRate: _formatStrokeRate(avgStrokeSpm),
      likes: likes,
      comments: comments,
      routeCoordinates: _extractRouteCoordinates(routeGeoJson),
    );
  }

  static String _resolveDisplayName({
    required String userId,
    String? displayName,
    String? username,
  }) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    if (username != null && username.trim().isNotEmpty) {
      return username.trim();
    }

    return _displayNameFromUserId(userId);
  }

  static String _displayNameFromUserId(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 8) {
      return trimmed;
    }
    return 'User ${trimmed.substring(0, 8)}';
  }

  static String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  static String _formatDistance(double? value) {
    if (value == null) {
      return '--';
    }
    return '${(value / 1000).toStringAsFixed(1)} km';
  }

  static String _formatDuration(int? value) {
    if (value == null || value <= 0) {
      return '--';
    }

    final hours = value ~/ 3600;
    final minutes = (value % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    final seconds = value % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }

    return '${seconds}s';
  }

  static String _formatAvgSplit(int? value) {
    if (value == null || value < 0) {
      return '--';
    }

    final minutes = value ~/ 60;
    final seconds = (value % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _formatStrokeRate(int? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return '$value s/m';
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

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

  static int _intOrZero(Object? value) {
    return _intOrNull(value) ?? 0;
  }

  static List<List<double>> _extractRouteCoordinates(Object? value) {
    if (value is! Map) {
      return const [];
    }

    final route = Map<String, dynamic>.from(value);
    final type = route['type']?.toString().trim() ?? '';
    if (type != 'LineString') {
      return const [];
    }

    final rawCoordinates = route['coordinates'];
    if (rawCoordinates is! List) {
      return const [];
    }

    final coordinates = <List<double>>[];
    for (final point in rawCoordinates) {
      if (point is! List || point.length < 2) {
        continue;
      }

      final lon = _doubleOrNull(point[0]);
      final lat = _doubleOrNull(point[1]);
      if (lon == null || lat == null) {
        continue;
      }

      coordinates.add([lon, lat]);
    }

    return coordinates;
  }

  static String? _normalizeAvatarUrl(String? value) {
    if (value == null) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.trim().isEmpty) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    return value;
  }
}
