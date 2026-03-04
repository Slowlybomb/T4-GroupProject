class Post {
  final String userName;
  final String? avatarUrl;
  final String timestamp;
  final String title;
  final String distance;
  final String duration;
  final String avgSplit;
  final String strokeRate;
  final int likes;

  const Post({
    required this.userName,
    this.avatarUrl,
    required this.timestamp,
    required this.title,
    required this.distance,
    required this.duration,
    required this.avgSplit,
    required this.strokeRate,
    this.likes = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Post &&
        other.userName == userName &&
        other.avatarUrl == avatarUrl &&
        other.timestamp == timestamp &&
        other.title == title &&
        other.distance == distance &&
        other.duration == duration &&
        other.avgSplit == avgSplit &&
        other.strokeRate == strokeRate &&
        other.likes == likes;
  }

  @override
  int get hashCode {
    return Object.hash(
      userName,
      avatarUrl,
      timestamp,
      title,
      distance,
      duration,
      avgSplit,
      strokeRate,
      likes,
    );
  }
}
