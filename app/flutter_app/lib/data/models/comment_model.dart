// lib/features/feed/view/comment.dart (or similar path)
class Comment {
  final String userName;
  final String text;
  final String timestamp;
  final String? avatarUrl;

  Comment({
    required this.userName,
    required this.text,
    required this.timestamp,
    this.avatarUrl,
  });
}