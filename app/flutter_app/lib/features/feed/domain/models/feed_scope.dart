enum FeedScope { following, global, friends }

extension FeedScopeUi on FeedScope {
  String get label {
    switch (this) {
      case FeedScope.following:
        return 'Following';
      case FeedScope.global:
        return 'Global';
      case FeedScope.friends:
        return 'Friends';
    }
  }
}
