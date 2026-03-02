

class ActivityModel {
  final String userName;
  final String timestamp;
  final String title;
  final String distance;
  final String duration;
  final String avgSplit;
  final String strokeRate;
  final int likes;

  ActivityModel({
    required this.userName,
    required this.timestamp,
    required this.title,
    required this.distance,
    required this.duration,
    required this.avgSplit,
    required this.strokeRate,
    this.likes = 0,
  });
}