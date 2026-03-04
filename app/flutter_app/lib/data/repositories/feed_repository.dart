import '../../core/network/api_error.dart';
import '../models/activity_dto.dart';
import '../models/activity_model.dart';
import '../models/follow_suggestion_dto.dart';
import '../models/metrics_summary_dto.dart';
import 'activity_api_repository.dart';

class FeedRepository {
  FeedRepository({
    required ActivityApiRepository activityApiRepository,
    required bool useLocalFallback,
  }) : _activityApiRepository = activityApiRepository,
       _useLocalFallback = useLocalFallback;

  final ActivityApiRepository _activityApiRepository;
  final bool _useLocalFallback;

  Future<List<ActivityModel>> getFeedActivities({required String scope}) async {
    try {
      final remoteActivities = await _activityApiRepository.listActivities(
        scope: scope,
      );
      if (remoteActivities.isNotEmpty) {
        return remoteActivities.map((dto) => dto.toActivityModel()).toList();
      }
      if (!_useLocalFallback) {
        return const [];
      }

      return _buildLocalFallbackFeed()
          .map((dto) => dto.toActivityModel())
          .toList(growable: false);
    } on ApiError {
      if (!_useLocalFallback) {
        rethrow;
      }
    } on FormatException {
      if (!_useLocalFallback) {
        rethrow;
      }
    }

    await Future.delayed(const Duration(milliseconds: 250));
    return _buildLocalFallbackFeed()
        .map((dto) => dto.toActivityModel())
        .toList(growable: false);
  }

  Future<void> followUser(String userId) {
    return _activityApiRepository.followUser(userId);
  }

  Future<ActivityModel> likeActivity(String id) async {
    final dto = await _activityApiRepository.likeActivity(id);
    return dto.toActivityModel();
  }

  Future<List<FollowSuggestionDto>> getFollowSuggestions({int limit = 5}) {
    return _activityApiRepository.listFollowSuggestions(limit: limit);
  }

  Future<MetricsSummaryDto> getMetricsSummary({
    required DateTime from,
    required DateTime to,
  }) {
    return _activityApiRepository.getMetricsSummary(from: from, to: to);
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
