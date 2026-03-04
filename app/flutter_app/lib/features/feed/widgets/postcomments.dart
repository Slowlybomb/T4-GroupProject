import 'package:flutter/material.dart';

// 1. SIMPLE DATA MODEL
class Comment {
  final String userName;
  final String text;
  final String timestamp;

  Comment({
    required this.userName,
    required this.text,
    required this.timestamp,
  });
}

class PostCommentsSheet extends StatefulWidget {
  const PostCommentsSheet({super.key});

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  // Mock data - in a real app, this would come from a Repository or Provider
  final List<Comment> _comments = [
    Comment(userName: 'Sarah D.', text: 'Great pace! 🚣‍♂️', timestamp: '2h'),
    Comment(userName: 'Mike R.', text: 'Liffey looking flat today.', timestamp: '1h'),
    Comment(userName: 'Jenny O.', text: 'Keep it up!', timestamp: '45m'),
  ];

  void _handleAddComment(String text) {
    setState(() {
      _comments.insert(0, Comment(
        userName: 'You',
        text: text,
        timestamp: 'Just now',
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // This pushes the UI up when the keyboard opens
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag Handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),

            // 2. THE COMMENT LIST
            Expanded(
              child: _comments.isEmpty 
                ? const Center(child: Text("No comments yet", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) => _CommentTile(comment: _comments[index]),
                  ),
            ),

            const Divider(height: 1),

            // 3. THE INPUT FIELD
            _CommentInputField(onSubmitted: _handleAddComment),
          ],
        ),
      ),
    );
  }
}

// SUB-WIDGET: Individual Comment Row
class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 16, backgroundColor: Colors.blueGrey, child: Icon(Icons.person, size: 18, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(comment.text, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(comment.timestamp, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SUB-WIDGET: The Input Field with Logic
class _CommentInputField extends StatefulWidget {
  final Function(String) onSubmitted;
  const _CommentInputField({required this.onSubmitted});

  @override
  State<_CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<_CommentInputField> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.blue),
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  widget.onSubmitted(_controller.text);
                  _controller.clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}