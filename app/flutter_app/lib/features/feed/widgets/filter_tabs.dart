import 'package:flutter/material.dart';

import '../../../core/theme/app_colour_theme.dart';
import '../domain/models/feed_scope.dart';

class FilterTabs extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.selectedScope,
    required this.onScopeSelected,
  });

  final FeedScope selectedScope;
  final ValueChanged<FeedScope> onScopeSelected;

  static const List<FeedScope> _tabs = [
    FeedScope.following,
    FeedScope.global,
    FeedScope.friends,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_tabs.length, (index) {
        final tab = _tabs[index];
        final isSelected = selectedScope == tab;
        return GestureDetector(
          onTap: () => onScopeSelected(tab),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryRed : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? null
                  : Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              tab.label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }
}
