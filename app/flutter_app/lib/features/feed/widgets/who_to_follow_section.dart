import 'package:flutter/material.dart';

import '../../../core/theme/app_colour_theme.dart';
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
  final Future<void> Function(FollowSuggestion suggestion) onFollowTap;
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
        const SizedBox(height: 15),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _FollowerCard(
                suggestion: suggestion,
                isFollowing: isFollowing(suggestion.id),
                onFollowTap: () => onFollowTap(suggestion),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _FollowerCard extends StatelessWidget {
  const _FollowerCard({
    required this.suggestion,
    required this.onFollowTap,
    required this.isFollowing,
  });

  final FollowSuggestion suggestion;
  final VoidCallback onFollowTap;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            radius: 25,
            backgroundImage: suggestion.avatarUrl == null
                ? null
                : NetworkImage(suggestion.avatarUrl!),
            child: suggestion.avatarUrl == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.headline,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '@${suggestion.userName}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isFollowing ? null : onFollowTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              disabledBackgroundColor: Colors.grey.shade400,
              shape: const StadiumBorder(),
              minimumSize: const Size(double.infinity, 30),
            ),
            child: Text(
              isFollowing ? 'Following...' : 'Follow',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
