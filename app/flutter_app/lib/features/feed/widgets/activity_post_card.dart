import 'package:flutter/material.dart';

import '../../../data/models/activity_model.dart';
import 'post_user_header.dart' as post_header;
import 'post_stats_row.dart' as post_stats;

class ActivityPostCard extends StatelessWidget {
  final ActivityModel activity;

  const ActivityPostCard({super.key, required this.activity});

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
          post_header.PostUserHeader(
            name: activity.userName,
            timeAgo: activity.timestamp,
            avatarUrl: activity.avatarUrl,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              activity.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          post_stats.PostStatsRow(
            distance: activity.distance,
            duration: activity.duration,
            avgSplit: activity.avgSplit,
            strokeRate: activity.strokeRate,
          ),
          const SizedBox(height: 15),
          // Map Placeholder
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
          _PostActions(likes: activity.likes),
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
