import 'package:flutter/foundation.dart';

class RoutePoint {
  final double longitude;
  final double latitude;

  const RoutePoint({required this.longitude, required this.latitude});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is RoutePoint &&
        other.longitude == longitude &&
        other.latitude == latitude;
  }

  @override
  int get hashCode => Object.hash(longitude, latitude);
}

class Post {
  final String id;
  final String userId;
  final String userName;
  final String? avatarUrl;
  final String timestamp;
  final String title;
  final String distance;
  final String duration;
  final String avgSplit;
  final String strokeRate;
  final int likes;
  final int comments;
  final List<RoutePoint> routePoints;

  const Post({
    this.id = '',
    this.userId = '',
    required this.userName,
    this.avatarUrl,
    required this.timestamp,
    required this.title,
    required this.distance,
    required this.duration,
    required this.avgSplit,
    required this.strokeRate,
    this.likes = 0,
    this.comments = 0,
    this.routePoints = const [],
  });

  Post copyWith({
    String? id,
    String? userId,
    String? userName,
    String? avatarUrl,
    String? timestamp,
    String? title,
    String? distance,
    String? duration,
    String? avgSplit,
    String? strokeRate,
    int? likes,
    int? comments,
    List<RoutePoint>? routePoints,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      avgSplit: avgSplit ?? this.avgSplit,
      strokeRate: strokeRate ?? this.strokeRate,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      routePoints: routePoints ?? this.routePoints,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Post &&
        other.id == id &&
        other.userId == userId &&
        other.userName == userName &&
        other.avatarUrl == avatarUrl &&
        other.timestamp == timestamp &&
        other.title == title &&
        other.distance == distance &&
        other.duration == duration &&
        other.avgSplit == avgSplit &&
        other.strokeRate == strokeRate &&
        other.likes == likes &&
        other.comments == comments &&
        listEquals(other.routePoints, routePoints);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      userName,
      avatarUrl,
      timestamp,
      title,
      distance,
      duration,
      avgSplit,
      strokeRate,
      likes,
      comments,
      Object.hashAll(routePoints),
    );
  }
}
