import 'package:flutter/material.dart';
import 'primarybutton.dart';

class NavigationRow extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const NavigationRow({super.key, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onBack,
            child: const CircleAvatar(
              backgroundColor: Colors.black,
              radius: 25,
              child: Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          PrimaryButton(text: "Next", onPressed: onNext),
        ],
      ),
    );
  }
}
