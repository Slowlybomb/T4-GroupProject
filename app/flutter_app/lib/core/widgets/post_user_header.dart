import 'package:flutter/material.dart';

class PostUserHeader extends StatelessWidget {
  static const String _dummyProfilePicturePath = 'assets/img/dummy-pp.png';

  final String name;
  final String timeAgo;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;

  const PostUserHeader({
    super.key,
    required this.name,
    required this.timeAgo,
    this.avatarUrl,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: ClipOval(child: _buildProfileImage()),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              timeAgo,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        const Icon(Icons.more_horiz, color: Colors.grey),
      ],
    );
  }

  Widget _buildProfileImage() {
    final imageUrl = avatarUrl?.trim();
    final uri = imageUrl == null ? null : Uri.tryParse(imageUrl);
    final hasValidHttpUrl =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    if (!hasValidHttpUrl) {
      return Image.asset(_dummyProfilePicturePath, fit: BoxFit.cover);
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(_dummyProfilePicturePath, fit: BoxFit.cover);
      },
    );
  }
}
