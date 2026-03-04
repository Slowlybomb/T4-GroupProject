class WeeklySummary {
  final DateTime from;
  final DateTime to;
  final int totalActivities;
  final double totalDistanceKm;

  const WeeklySummary({
    required this.from,
    required this.to,
    required this.totalActivities,
    required this.totalDistanceKm,
  });
}
