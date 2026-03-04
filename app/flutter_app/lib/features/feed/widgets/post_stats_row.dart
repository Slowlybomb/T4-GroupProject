import 'package:flutter/material.dart';
import '../domain/models/post.dart';
import '../../../core/widgets/post_user_header.dart';
import 'post_actions.dart';

class PostStatsScreen extends StatelessWidget {
  final Post post;

  const PostStatsScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Main Content
          SingleChildScrollView(
            // Use ClampingScrollPhysics to stop the "bounce" effect at the top
            physics: const ClampingScrollPhysics(), 
            child: Column(
              children: [
                // Map Header
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  width: double.infinity,
                  color: Colors.blue.shade50,
                  child: const Icon(Icons.map_outlined, color: Colors.blue, size: 60),
                ),

                // White Content Box
                Container(
                  width: double.infinity,
                  // This pulls the box up slightly to overlap the map if desired, 
                  // or remove the transform for a clean break.
                  transform: Matrix4.translationValues(0, -25, 0), 
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PostUserHeader(
                          name: post.userName,
                          timeAgo: post.timestamp,
                          avatarUrl: post.avatarUrl,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Data Grid
                        _buildDataGrid(),

                        const SizedBox(height: 32),
                        const Text(
                          'Stroke Analysis',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildStrokeChart(),

                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),

                        // Social Actions
                        PostActions(likes: post.likes, post: post),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Fixed Floating Buttons
          _buildFixedButtons(context),
        ],
      ),
    );
  }

  // --- Helper methods remain the same as previous script ---
  
  Widget _buildFixedButtons(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCircleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
            _buildCircleButton(
              icon: Icons.bookmark_border,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.9),
      child: IconButton(
        icon: Icon(icon, color: Colors.black, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildDataGrid() {
    return Column(
      children: [
        Row(
          children: [
            _StatTile(label: 'Distance', value: post.distance, icon: Icons.straighten),
            _StatTile(label: 'Duration', value: post.duration, icon: Icons.timer_outlined),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatTile(label: 'Avg Split', value: post.avgSplit, icon: Icons.speed),
            _StatTile(label: 'Stroke Rate', value: post.strokeRate, icon: Icons.waves),
          ],
        ),
      ],
    );
  }

  Widget _buildStrokeChart() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(child: Icon(Icons.show_chart, color: Colors.blue)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.blue),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}