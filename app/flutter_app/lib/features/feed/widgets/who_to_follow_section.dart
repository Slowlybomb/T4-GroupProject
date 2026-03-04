import 'package:flutter/material.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../profile/view/user_profile_screen.dart';

class WhoToFollowSection extends StatelessWidget {
  const WhoToFollowSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Demo suggestions stay local until backend "follow suggestions" API exists.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Who to follow",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: 5,
            itemBuilder: (context, index) => _FollowerCard(name: 'Rower ${index + 1}'),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _FollowerCard extends StatelessWidget {
  final String name;
  const _FollowerCard({required this.name});

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(name: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openProfile(context),
      child: Container(
        width: 120,
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
            GestureDetector(
              onTap: () => _openProfile(context),
              child: const CircleAvatar(backgroundColor: Colors.grey, radius: 25),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                shape: const StadiumBorder(),
                minimumSize: const Size(double.infinity, 30),
              ),
              child: const Text("Follow", style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
