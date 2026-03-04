import 'package:flutter/material.dart';

import '../../../core/theme/app_colour_theme.dart';
import '../../profile/view/user_profile_screen.dart';
import '../domain/models/follow_suggestion.dart';

class WhoToFollowSection extends StatelessWidget {
  const WhoToFollowSection({
    super.key,
    required this.suggestions,
    required this.onFollowTap,
    required this.isFollowing,
    this.errorMessage,
  });

  final List<FollowSuggestion> suggestions;
  final Future<bool> Function(FollowSuggestion suggestion) onFollowTap;
  final bool Function(String userId) isFollowing;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty && errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Who to follow',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 15),
          SizedBox(
            height: 175,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return _FollowerCard(
                  suggestion: suggestion,
                  isFollowing: isFollowing(suggestion.id),
                  onFollowTap: onFollowTap,
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _FollowerCard extends StatefulWidget {
  const _FollowerCard({
    required this.suggestion,
    required this.isFollowing,
    required this.onFollowTap,
  });

  final FollowSuggestion suggestion;
  final bool isFollowing;
  final Future<bool> Function(FollowSuggestion suggestion) onFollowTap;

  @override
  State<_FollowerCard> createState() => _FollowerCardState();
}

class _FollowerCardState extends State<_FollowerCard> {
  bool _isSubmitting = false;

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(name: widget.suggestion.headline),
      ),
    );
  }

  Future<void> _follow() async {
    if (_isSubmitting || widget.isFollowing) {
      return;
    }

    setState(() => _isSubmitting = true);
    await widget.onFollowTap(widget.suggestion);
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isFollowing ? 'Following' : 'Follow';

    return GestureDetector(
      onTap: () => _openProfile(context),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            const CircleAvatar(backgroundColor: Colors.grey, radius: 25),
            const SizedBox(height: 10),
            Text(
              widget.suggestion.headline,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _follow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isFollowing
                      ? Colors.transparent
                      : AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(30),
                  border: widget.isFollowing
                      ? Border.all(color: Colors.grey.shade400)
                      : null,
                ),
                alignment: Alignment.center,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isFollowing
                              ? Colors.grey.shade600
                              : Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
