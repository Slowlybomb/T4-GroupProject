class ActivityModel {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String timestamp;
  final String title;
  final String distance;
  final String duration;
  final String avgSplit;
  final String strokeRate;
  final int likes;
  final int comments;
  final List<List<double>> routeCoordinates;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.timestamp,
    required this.title,
    required this.distance,
    required this.duration,
    required this.avgSplit,
    required this.strokeRate,
    this.likes = 0,
    this.comments = 0,
    this.routeCoordinates = const [],
  });
}
