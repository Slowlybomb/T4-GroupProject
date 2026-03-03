import '../../core/network/api_error.dart';
import '../models/activity_dto.dart';
import '../models/activity_model.dart';
import 'activity_api_repository.dart';

class FeedRepository {
  final ActivityApiRepository _activityApiRepository;
  final bool _useLocalFallback;

  FeedRepository({
    required ActivityApiRepository activityApiRepository,
    required bool useLocalFallback,
  }) : _activityApiRepository = activityApiRepository,
       _useLocalFallback = useLocalFallback;

  Future<List<ActivityModel>> getFeedActivities() async {
    try {
      // Primary source: backend activities endpoint.
      final remoteActivities = await _activityApiRepository.listActivities();
      if (remoteActivities.isNotEmpty) {
        return remoteActivities.map((dto) => dto.toActivityModel()).toList();
      }

      // Keep the feed populated for demo/early-stage environments where the
      // backend is reachable but currently has no activities.
      return _buildLocalFallbackFeed()
          .map((dto) => dto.toActivityModel())
          .toList();
    } on ApiError {
      if (!_useLocalFallback) {
        rethrow;
      }
    } on FormatException {
      if (!_useLocalFallback) {
        rethrow;
      }
    }

    if (!_useLocalFallback) {
      return const [];
    }

    // Optional demo/offline path when API is unavailable.
    await Future.delayed(const Duration(milliseconds: 250));
    return _buildLocalFallbackFeed()
        .map((dto) => dto.toActivityModel())
        .toList();
  }

  List<ActivityDto> _buildLocalFallbackFeed() {
    final now = DateTime.now().toUtc();

    return [
      ActivityDto(
        id: '00000000-0000-0000-0000-000000000001',
        userId: 'fallback-hugo',
        username: 'hugo',
        displayName: 'Hugo',
        title: 'Hard session on the ergometer today!',
        notes: null,
        startTime: now.subtract(const Duration(hours: 2)),
        durationSeconds: 72 * 60,
        distanceM: 33200,
        avgSplit500mSeconds: 130,
        avgStrokeSpm: 24,
        visibility: 'public',
        teamId: null,
        routeGeoJson: null,
        likes: 12,
        comments: 0,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ActivityDto(
        id: '00000000-0000-0000-0000-000000000002',
        userId: 'fallback-sarah',
        username: 'sarah',
        displayName: 'Sarah',
        title: 'Morning 5k piece, feeling strong.',
        notes: null,
        startTime: now.subtract(const Duration(hours: 5)),
        durationSeconds: 18 * 60 + 30,
        distanceM: 5000,
        avgSplit500mSeconds: 111,
        avgStrokeSpm: 28,
        visibility: 'public',
        teamId: null,
        routeGeoJson: null,
        likes: 8,
        comments: 0,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
  }
}
