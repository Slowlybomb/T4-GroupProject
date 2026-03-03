import 'package:flutter/material.dart';

import '../data/feed_repository.dart';
import '../domain/models/post.dart';

class FeedController extends ChangeNotifier {
  final FeedRepository _feedRepository;

  FeedController({required FeedRepository feedRepository})
    : _feedRepository = feedRepository;

  List<Post> _posts = const [];
  bool _isLoading = false;
  String? _errorMessage;
  Post? _selectedPost;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Post? get selectedPost => _selectedPost;

  Future<void> loadPosts() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _posts = await _feedRepository.getPosts();
    } catch (_) {
      _errorMessage = 'Unable to load feed right now.';
      _posts = const [];
    } finally {
      _isLoading = false;
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
}
