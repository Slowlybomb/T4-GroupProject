class FollowSuggestionDto {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? lastPublicActivity;

  const FollowSuggestionDto({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.lastPublicActivity,
  });

  factory FollowSuggestionDto.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final username = json['username']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Follow suggestion id is missing');
    }
    if (username.isEmpty) {
      throw const FormatException('Follow suggestion username is missing');
    }

    return FollowSuggestionDto(
      id: id,
      username: username,
      displayName: _stringOrNull(json['display_name']),
      avatarUrl: _stringOrNull(json['avatar_url']),
      lastPublicActivity: _dateTimeOrNull(json['last_public_activity']),
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }
}
