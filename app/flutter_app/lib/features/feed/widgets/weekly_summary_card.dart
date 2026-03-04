import 'package:flutter/material.dart';

import '../../../core/theme/app_colour_theme.dart';
import '../domain/models/weekly_summary.dart';

class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({
    super.key,
    required this.summary,
    required this.onViewProgress,
    this.errorMessage,
    this.isLoading = false,
  });

  final WeeklySummary? summary;
  final VoidCallback onViewProgress;
  final String? errorMessage;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final distanceValue = summary == null
        ? '--'
        : '${summary!.totalDistanceKm.toStringAsFixed(1)} km';
    final activitiesValue = summary == null
        ? '--'
        : '${summary!.totalActivities}';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(label: 'Distance', value: distanceValue),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Activities',
                  value: activitiesValue,
                ),
              ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(color: Colors.white, minHeight: 2),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(errorMessage!, style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewProgress,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'View progress',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
