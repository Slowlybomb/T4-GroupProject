import 'package:flutter/material.dart';

import '../data/feed_repository.dart';
import '../domain/models/feed_scope.dart';
import '../domain/models/follow_suggestion.dart';
import '../domain/models/post.dart';
import '../domain/models/weekly_summary.dart';

class FeedController extends ChangeNotifier {
  FeedController({required FeedRepository feedRepository})
    : _feedRepository = feedRepository;

  final FeedRepository _feedRepository;

  List<Post> _posts = const [];
  List<FollowSuggestion> _suggestions = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _summaryErrorMessage;
  String? _suggestionsErrorMessage;
  WeeklySummary? _weeklySummary;
  FeedScope _selectedScope = FeedScope.following;
  Post? _selectedPost;
  final Set<String> _likingPostIds = <String>{};
  final Set<String> _followingUserIds = <String>{};

  List<Post> get posts => _posts;
  List<FollowSuggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get summaryErrorMessage => _summaryErrorMessage;
  String? get suggestionsErrorMessage => _suggestionsErrorMessage;
  WeeklySummary? get weeklySummary => _weeklySummary;
  FeedScope get selectedScope => _selectedScope;
  Post? get selectedPost => _selectedPost;

  bool isLiking(String postId) => _likingPostIds.contains(postId);

  bool isFollowing(String userId) => _followingUserIds.contains(userId);

  Future<void> loadPosts({FeedScope? scope}) async {
    if (_isLoading) {
      return;
    }
    if (scope != null) {
      _selectedScope = scope;
    }

    _isLoading = true;
    _errorMessage = null;
    _summaryErrorMessage = null;
    _suggestionsErrorMessage = null;
    notifyListeners();

    try {
      // Feed list drives the main scroll body, so load it first.
      _posts = await _feedRepository.getPosts(scope: _selectedScope);
    } catch (_) {
      _errorMessage = 'Unable to load feed right now.';
      _posts = const [];
    }

    final weeklyRange = _resolveCurrentWeekRange();
    try {
      _weeklySummary = await _feedRepository.getWeeklySummary(
        from: weeklyRange.from,
        to: weeklyRange.to,
      );
    } catch (_) {
      _weeklySummary = null;
      _summaryErrorMessage = 'Unable to load weekly summary.';
    }

    try {
      _suggestions = await _feedRepository.getFollowSuggestions();
    } catch (_) {
      _suggestions = const [];
      _suggestionsErrorMessage = 'Unable to load follow suggestions.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> changeScope(FeedScope scope) async {
    if (_selectedScope == scope) {
      return;
    }
    await loadPosts(scope: scope);
  }

  Future<bool> likePost(Post post) async {
    final postId = post.id.trim();
    if (postId.isEmpty || _likingPostIds.contains(postId)) {
      return false;
    }

    _likingPostIds.add(postId);
    // Optimistic update keeps UI responsive while backend call is in-flight.
    final optimistic = post.copyWith(likes: post.likes + 1);
    _replacePost(optimistic);
    notifyListeners();

    try {
      final updated = await _feedRepository.likePost(postId);
      _replacePost(updated);
      return true;
    } catch (_) {
      _replacePost(post);
      return false;
    } finally {
      _likingPostIds.remove(postId);
      notifyListeners();
    }
  }

  Future<bool> followSuggestion(FollowSuggestion suggestion) async {
    final userId = suggestion.id.trim();
    if (userId.isEmpty || _followingUserIds.contains(userId)) {
      return false;
    }

    _followingUserIds.add(userId);
    notifyListeners();

    try {
      await _feedRepository.followUser(userId);
      _suggestions = _suggestions
          .where((candidate) => candidate.id != userId)
          .toList(growable: false);
      return true;
    } catch (_) {
      return false;
    } finally {
      _followingUserIds.remove(userId);
      notifyListeners();
    }
  }

  void selectPost(Post post) {
    _selectedPost = post;
    notifyListeners();
  }

  void clearSelectedPost() {
    if (_selectedPost == null) {
      return;
    }

    _selectedPost = null;
    notifyListeners();
  }

  void _replacePost(Post replacement) {
    _posts = _posts
        .map((post) => post.id == replacement.id ? replacement : post)
        .toList(growable: false);
    if (_selectedPost?.id == replacement.id) {
      _selectedPost = replacement;
    }
  }

  _WeekRange _resolveCurrentWeekRange() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    // App defines weekly summary as calendar week-to-date (Monday start).
    final monday = startOfDay.subtract(Duration(days: now.weekday - 1));
    return _WeekRange(from: monday.toUtc(), to: now.toUtc());
  }
}

class _WeekRange {
  final DateTime from;
  final DateTime to;

  const _WeekRange({required this.from, required this.to});
}
