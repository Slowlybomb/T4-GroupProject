import '../models/activity_model.dart';

class FeedRepository {
  // This simulates fetching data from a server or local database
  Future<List<ActivityModel>> getFeedActivities() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1)); 

    // Return dummy data using our ActivityModel
    return [
      ActivityModel(
        userName: "Hugo",
        timestamp: "2h ago",
        title: "Hard session on the ergometer today!",
        distance: "33.2 km",
        duration: "1h 12m",
        avgSplit: "2:10",
        strokeRate: "24 s/m",
      ),
      ActivityModel(
        userName: "Sarah",
        timestamp: "5h ago",
        title: "Morning 5k piece, feeling strong.",
        distance: "5.0 km",
        duration: "18m 30s",
        avgSplit: "1:51",
        strokeRate: "28 s/m",
      ),
    ];
  }
}