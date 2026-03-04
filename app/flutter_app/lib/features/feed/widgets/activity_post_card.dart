import 'package:flutter/material.dart';
import '../domain/models/post.dart';
import 'post_actions.dart';
import 'post_map.dart';

// Core design system widgets
import '../../../core/widgets/post_stats_row.dart';
import '../../../core/widgets/post_user_header.dart';

class ActivityPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onAvatarTap;

  const ActivityPostCard({super.key, required this.post, this.onAvatarTap});

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
            padding: const EdgeInsets.symmetric(vertical: 12.0),
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