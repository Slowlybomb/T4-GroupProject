import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/post_stats_row.dart';
import '../../../core/widgets/post_user_header.dart';
import '../../feed/domain/models/post.dart';
import '../widgets/orange_line_painter.dart';

// ─── Comment data model ───────────────────────────────────────────────────────
class _CommentData {
  final String name;
  final String timeAgo;
  final String text;
  _CommentData({required this.name, required this.timeAgo, required this.text});
}

final _kInitialComments = [
  _CommentData(name: 'Hugo E.', timeAgo: '1 hour ago', text: 'Great session! That split is impressive 🚣'),
  _CommentData(name: 'Mark K.', timeAgo: '30 min ago', text: 'Nice pace, keep it up!'),
  _CommentData(name: 'Sophie M.', timeAgo: '15 min ago', text: 'That distance is serious work 💪'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────
class PostDetailScreen extends StatefulWidget {
  final Post post;
  final VoidCallback onClose;
  final VoidCallback? onAvatarTap;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.onClose,
    this.onAvatarTap,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _scrollController = ScrollController();
  final _commentsKey = GlobalKey();
  int _commentCount = _kInitialComments.length;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToComments() {
    final ctx = _commentsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildGraphHeader(),
          Positioned(
            top: 220,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  const _DragHandle(),
                  const SizedBox(height: 12),
                  // ── Sticky user header ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: PostUserHeader(
                      name: widget.post.userName,
                      timeAgo: widget.post.timestamp,
                      avatarUrl: widget.post.avatarUrl,
                      onAvatarTap: widget.onAvatarTap,
                    ),
                  ),
                  const Divider(height: 16, indent: 25, endIndent: 25),
                  // ── Scrollable content ──────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post.title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          PostStatsRow(
                            distance: widget.post.distance,
                            duration: widget.post.duration,
                            avgSplit: widget.post.avgSplit,
                            strokeRate: widget.post.strokeRate,
                          ),
                          const SizedBox(height: 30),
                          _ActionBar(
                            likes: widget.post.likes,
                            commentCount: _commentCount,
                            onCommentTap: _scrollToComments,
                          ),
                          const SizedBox(height: 24),
                          _CommentsSection(
                            key: _commentsKey,
                            onCommentAdded: () =>
                                setState(() => _commentCount++),
                          ),
                          const SizedBox(height: 40),
                          const _BackgroundWatermark(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphHeader() {
    return SizedBox(
      height: 250,
      child: Stack(
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.white70,
                    child: Icon(Icons.arrow_back, color: Colors.red),
                  ),
                  onPressed: widget.onClose,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SaveButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Drag handle ─────────────────────────────────────────────────────────────
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ─── Save button ──────────────────────────────────────────────────────────────
class _SaveButton extends StatefulWidget {
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: CircleAvatar(
        backgroundColor: Colors.white70,
        child: Icon(
          _saved ? Icons.bookmark : Icons.bookmark_border,
          color: _saved ? Colors.red : Colors.grey.shade700,
        ),
      ),
      onPressed: () => setState(() => _saved = !_saved),
    );
  }
}

// ─── Interactive action bar ───────────────────────────────────────────────────
class _ActionBar extends StatefulWidget {
  final int likes;
  final int commentCount;
  final VoidCallback? onCommentTap;

  const _ActionBar({
    required this.likes,
    required this.commentCount,
    this.onCommentTap,
  });

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  bool _liked = false;

  int get _displayCount => widget.likes + (_liked ? 1 : 0);

  void _toggleLike() => setState(() => _liked = !_liked);

  void _share(BuildContext context) {
    Clipboard.setData(
        const ClipboardData(text: 'https://gondolier.app/activity/1'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionBtn(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          label: '$_displayCount',
          color: _liked ? Colors.red : Colors.grey,
          onTap: _toggleLike,
        ),
        _ActionBtn(
          icon: Icons.chat_bubble_outline,
          label: '${widget.commentCount}',
          color: Colors.grey,
          onTap: () => widget.onCommentTap?.call(),
        ),
        _ActionBtn(
          icon: Icons.share_outlined,
          label: 'Share',
          color: Colors.grey,
          onTap: () => _share(context),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

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

// ─── Comments section (stateful — supports adding comments) ───────────────────
class _CommentsSection extends StatefulWidget {
  final VoidCallback onCommentAdded;
  const _CommentsSection({super.key, required this.onCommentAdded});

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _inputCtrl = TextEditingController();
  late final List<_CommentData> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List.of(_kInitialComments);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.add(_CommentData(name: 'You', timeAgo: 'just now', text: text));
      _inputCtrl.clear();
    });
    widget.onCommentAdded();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments (${_comments.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._comments.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CommentTile(data: c),
            )),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final _CommentData data;
  const _CommentTile({required this.data});

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
                  Text(data.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(data.timeAgo,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 3),
              Text(data.text, style: const TextStyle(fontSize: 13)),
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
