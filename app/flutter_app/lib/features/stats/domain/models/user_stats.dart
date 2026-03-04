class TrainingLogEntry {
  final String label;
  final bool highlighted;

  const TrainingLogEntry({required this.label, this.highlighted = false});
}

class UserStats {
  final double weeklyDistanceKm;
  final int weeklyMinutes;
  final String trainingLogDateRange;
  final List<TrainingLogEntry> trainingLogEntries;

  const UserStats({
    required this.weeklyDistanceKm,
    required this.weeklyMinutes,
    required this.trainingLogDateRange,
    required this.trainingLogEntries,
  });
}
