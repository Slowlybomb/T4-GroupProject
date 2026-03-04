import 'package:flutter/material.dart';
import '../domain/models/post.dart';
import 'post_actions.dart';
import 'post_map.dart';

// Core design system widgets
import '../../../core/widgets/post_stats_row.dart';
import '../../../core/widgets/post_user_header.dart';

class ActivityPostCard extends StatelessWidget {
  const ActivityPostCard({
    super.key,
    required this.post,
    this.onAvatarTap,
    this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
  });

  final Post post;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostUserHeader(
            name: post.userName,
            timeAgo: post.timestamp,
            avatarUrl: post.avatarUrl,
            onAvatarTap: onAvatarTap,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              post.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          PostStatsRow(
            distance: post.distance,
            duration: post.duration,
            avgSplit: post.avgSplit,
            strokeRate: post.strokeRate,
          ),
          const SizedBox(height: 15),
          _RoutePreview(routePoints: post.routePoints),
          const SizedBox(height: 15),
          _PostActions(
            likes: post.likes,
            onLikeTap: onLikeTap,
            onCommentTap: onCommentTap,
            onShareTap: onShareTap,
          ),
        ],
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({required this.routePoints});

  final List<RoutePoint> routePoints;

  @override
  Widget build(BuildContext context) {
    if (routePoints.length < 2) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.map_outlined, color: Colors.blue, size: 40),
      );
    }

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.all(10),
      child: CustomPaint(painter: _RoutePolylinePainter(routePoints)),
    );
  }
}

class _RoutePolylinePainter extends CustomPainter {
  const _RoutePolylinePainter(this.routePoints);

  final List<RoutePoint> routePoints;

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) {
      return;
    }

    var minLon = routePoints.first.longitude;
    var maxLon = routePoints.first.longitude;
    var minLat = routePoints.first.latitude;
    var maxLat = routePoints.first.latitude;

    for (final point in routePoints) {
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
    }

    final lonSpan = (maxLon - minLon).abs();
    final latSpan = (maxLat - minLat).abs();
    final effectiveLonSpan = lonSpan == 0 ? 1.0 : lonSpan;
    final effectiveLatSpan = latSpan == 0 ? 1.0 : latSpan;
    const padding = 12.0;
    final width = size.width - padding * 2;
    final height = size.height - padding * 2;

    final path = Path();
    for (var index = 0; index < routePoints.length; index++) {
      final point = routePoints[index];
      // Convert geo coordinates into local [0..1] bounds so any route fits card.
      final normalizedX = (point.longitude - minLon) / effectiveLonSpan;
      final normalizedY = (point.latitude - minLat) / effectiveLatSpan;
      final x = padding + normalizedX * width;
      final y = padding + (1 - normalizedY) * height;

      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RoutePolylinePainter oldDelegate) {
    return oldDelegate.routePoints != routePoints;
          const SizedBox(height: 15),
          // Replaced placeholder with the hardcoded map
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: StaticRowingMap(),
            ),
          ),
          const SizedBox(height: 15),
          Padding(
  padding: const EdgeInsets.only(top: 15), 
  child: PostActions(likes: post.likes , post: post),
)
        ],
      ),
    );
  }
}

class _PostActions extends StatelessWidget {
  final int likes;

  const _PostActions({required this.likes});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.favorite_border, color: Colors.red, size: 20),
        const SizedBox(width: 5),
        Text('$likes', style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 15),
        const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
        const Spacer(),
        const Icon(Icons.share_outlined, color: Colors.grey, size: 20),
      ],
    );
  }
}
