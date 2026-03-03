import 'package:flutter/material.dart';

import '../../../core/widgets/post_stats_row.dart';
import '../../../core/widgets/post_user_header.dart';
import '../../feed/domain/models/post.dart';
import '../widgets/orange_line_painter.dart';

class PostDetailScreen extends StatelessWidget {
  final Post post;
  final VoidCallback onClose;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildGraphHeader(),
          Expanded(
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -30, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DragHandle(),
                    const SizedBox(height: 20),
                    PostUserHeader(
                      name: post.userName,
                      timeAgo: post.timestamp,
                      avatarUrl: post.avatarUrl,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    PostStatsRow(
                      distance: post.distance,
                      duration: post.duration,
                      avgSplit: post.avgSplit,
                      strokeRate: post.strokeRate,
                    ),
                    const SizedBox(height: 40),
                    _ActionIcons(likes: post.likes),
                    const SizedBox(height: 40),
                    const _BackgroundWatermark(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphHeader() {
    return Stack(
      children: [
        Container(
          height: 250,
          width: double.infinity,
          color: const Color(0xFF2C3E50),
          child: Center(
            child: CustomPaint(
              size: const Size(300, 100),
              painter: OrangeLinePainter(),
            ),
          ),
        ),
        SafeArea(
          child: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white70,
              child: Icon(Icons.arrow_back, color: Colors.red),
            ),
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _ActionIcons extends StatelessWidget {
  final int likes;

  const _ActionIcons({required this.likes});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionButton(Icons.favorite_border, 'Like ($likes)'),
        _actionButton(Icons.chat_bubble_outline, 'Comment'),
        _actionButton(Icons.share_outlined, 'Share'),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.red, size: 28),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _BackgroundWatermark extends StatelessWidget {
  const _BackgroundWatermark();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'GONDOLIER',
        style: TextStyle(
          fontSize: 60,
          fontWeight: FontWeight.bold,
          color: Color(0x05000000),
        ),
      ),
    );
  }
}
