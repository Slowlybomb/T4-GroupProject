import 'package:flutter/material.dart';
import '../theme/app_colour_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        elevation: 0,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
        ],
      ),
    );
  }
}