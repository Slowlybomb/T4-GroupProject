import 'package:flutter/material.dart';
import 'postcomments.dart'; 
import '../domain/models/post.dart';// Assuming you rename postcomments.dart
import 'package:share_plus/share_plus.dart';
class PostActions extends StatefulWidget {
  final int likes;
  final Post post;
  const PostActions({super.key, required this.likes, required this.post});

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  bool _liked = false;
  void _handleShare() async {
    // 1. Get the render box for iPad/Tablet support
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    
    final String message = 
        'Check out this rowing session! 🚣‍♂️\n'
        'Distance: ${widget.post.distance}\n'
        'Time: ${widget.post.duration}\n'
        'Average Split: ${widget.post.avgSplit}';

    // 2. Trigger the native Share Sheet
    await Share.share(
      message, 
      subject: 'My Rowing Stats',
      // Required for iPads to know where the popup comes from
      sharePositionOrigin: box != null 
          ? box.localToGlobal(Offset.zero) & box.size 
          : null,
    );
  }
  int get _likeCount => widget.likes + (_liked ? 1 : 0);

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PostCommentsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionItem(
          
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          label: '$_likeCount',
          color: Colors.red,
          onTap: () => setState(() => _liked = !_liked),
        ),
        const SizedBox(width: 15),
        _ActionItem(
          icon: Icons.chat_bubble_outline,
          label: '3',
          color: Colors.grey,
          onTap: () => _showComments(context),
        ),
        const Spacer(),
        _ActionItem(
        icon: Icons.share_outlined,
        label: 'Share',
        color: Colors.grey,
        onTap: () {
        print("Share button pressed!"); // If this doesn't show in console, the tap isn't reaching the code
        _handleShare();
      },
      ), ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}