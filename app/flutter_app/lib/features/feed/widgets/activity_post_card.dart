import 'package:flutter/material.dart';
import 'post_user_header.dart' as post_header;
import 'post_stats_row.dart' as post_stats;

class ActivityPostCard extends StatelessWidget {
  const ActivityPostCard({super.key});

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
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ADDED PREFIX HERE
          const post_header.PostUserHeader(name: 'Hugo', timeAgo: '2h ago'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'Hard session on the ergometer today!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          // ADDED PREFIX HERE
          const post_stats.PostStatsRow(),
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
          const _PostActions(),
        ],
      ),
    );
  }
}

class _PostActions extends StatelessWidget {
  const _PostActions();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.favorite_border, color: Colors.red, size: 20),
        SizedBox(width: 5),
        Text('12', style: TextStyle(fontSize: 12)),
        SizedBox(width: 15),
        Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
        Spacer(),
        Icon(Icons.share_outlined, color: Colors.grey, size: 20),
      ],
    );
  }
}