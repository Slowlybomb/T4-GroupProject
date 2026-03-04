class FollowSuggestion {
  final String id;
  final String userName;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? lastPublicActivity;

  const FollowSuggestion({
    required this.id,
    required this.userName,
    this.displayName,
    this.avatarUrl,
    this.lastPublicActivity,
  });

  String get headline {
    final candidate = displayName?.trim() ?? '';
    if (candidate.isNotEmpty) {
      return candidate;
    }
    return userName;
  }
}
