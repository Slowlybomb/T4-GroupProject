import 'package:flutter/material.dart';

import '../../../core/widgets/post_stats_row.dart';
import '../../../core/widgets/post_user_header.dart';
import '../../feed/domain/models/post.dart';
import '../widgets/orange_line_painter.dart';

class PostDetailScreen extends StatelessWidget {
  final Post post;
  final VoidCallback onClose;
  final VoidCallback? onAvatarTap;
  final Future<void> Function(Post post)? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onClose,
    this.onAvatarTap,
    this.onLike,
    this.onComment,
    this.onShare,
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
                      onAvatarTap: onAvatarTap,
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
                    const SizedBox(height: 30),
                    _ActionBar(
                      likes: post.likes,
                      onLike: onLike == null ? null : () => onLike!(post),
                      onComment: onComment,
                      onShare: onShare,
                    ),
                    const SizedBox(height: 24),
                    const _CommentsSection(),
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

// ─── Drag handle ─────────────────────────────────────────────────────────────
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

// ─── Interactive action bar ───────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final int likes;
  final Future<void> Function()? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  const _ActionBar({
    required this.likes,
    this.onLike,
    this.onComment,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionBtn(
          icon: Icons.favorite_border,
          label: '$likes',
          color: Colors.grey,
          onTap: () => onLike?.call(),
        ),
        _ActionBtn(
          icon: Icons.chat_bubble_outline,
          label: 'Comment',
          color: Colors.grey,
          onTap: onComment,
        ),
        _ActionBtn(
          icon: Icons.share_outlined,
          label: 'Share',
          color: Colors.grey,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ─── Comments section ─────────────────────────────────────────────────────────
class _CommentsSection extends StatelessWidget {
  const _CommentsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comments',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _CommentTile(
          name: 'Hugo E.',
          timeAgo: '1 hour ago',
          text: 'Great session! That split is impressive 🚣',
        ),
        const SizedBox(height: 10),
        _CommentTile(
          name: 'Mark K.',
          timeAgo: '30 min ago',
          text: 'Nice pace, keep it up!',
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: 'Add a comment…',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            suffixIcon: const Icon(Icons.send, color: Colors.red),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final String name;
  final String timeAgo;
  final String text;

  const _CommentTile({
    required this.name,
    required this.timeAgo,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(backgroundColor: Colors.grey, radius: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Watermark ────────────────────────────────────────────────────────────────
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
