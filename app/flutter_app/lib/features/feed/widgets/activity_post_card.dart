import 'package:flutter/material.dart';

import '../../../core/widgets/post_stats_row.dart' as post_stats;
import '../../../core/widgets/post_user_header.dart' as post_header;
import '../domain/models/post.dart';

class ActivityPostCard extends StatelessWidget {
  final Post post;

  const ActivityPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // Post card consumes feature-domain `Post`, decoupled from API DTOs.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          post_header.PostUserHeader(
            name: post.userName,
            timeAgo: post.timestamp,
            avatarUrl: post.avatarUrl,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              post.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          post_stats.PostStatsRow(
            distance: post.distance,
            duration: post.duration,
            avgSplit: post.avgSplit,
            strokeRate: post.strokeRate,
          ),
          const SizedBox(height: 15),
          // TODO: replace with actual route map when map rendering is available.
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.map_outlined, color: Colors.blue, size: 40),
          ),
          const SizedBox(height: 15),
          _PostActions(likes: post.likes),
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
