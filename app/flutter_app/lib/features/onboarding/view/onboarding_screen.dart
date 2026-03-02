import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_colour_theme.dart';
import '../../../core/widgets/primarybutton.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  bool _isLastPage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Carousel
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => _isLastPage = index == 2);
            },
            children: const [
              _OnboardingPage(
                icon: Icons.waves,
                title: "Track Your Rowing",
                description: "Record every stroke, split, and session.",
              ),
              _OnboardingPage(
                icon: Icons.group,
                title: "Join the Community",
                description: "Connect with rowers around the world.",
              ),
              _OnboardingPage(
                icon: Icons.trending_up,
                title: "Analyze Progress",
                description: "Visualize your performance gains.",
              ),
            ],
          ),

          // 2. Skip Button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: widget.onFinish,
              child: const Text("Skip", style: TextStyle(color: Colors.grey)),
            ),
          ),

          // 3. Indicator and Button
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: const WormEffect(
                    activeDotColor: AppColors.primaryRed,
                    dotColor: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),
                if (_isLastPage)
                  PrimaryButton(text: "Get Started", onPressed: widget.onFinish)
                else
                  const SizedBox(height: 50), // Placeholder to keep layout steady
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 4. The Individual Page Widget
class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: AppColors.primaryRed),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}