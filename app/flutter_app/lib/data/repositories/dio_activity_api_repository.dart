import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_error.dart';
import '../models/activity_dto.dart';
import '../models/create_activity_request_dto.dart';
import '../models/follow_suggestion_dto.dart';
import '../models/metrics_summary_dto.dart';
import 'activity_api_repository.dart';

class DioActivityApiRepository implements ActivityApiRepository {
  DioActivityApiRepository(
    this._dio, {
    Future<Object?> Function()? loadDefaultRouteGeoJson,
  }) : _loadDefaultRouteGeoJson =
           loadDefaultRouteGeoJson ?? _loadDummyTrainingPathGeoJson;

  final Dio _dio;
  final Future<Object?> Function() _loadDefaultRouteGeoJson;
  Object? _cachedDefaultRouteGeoJson;

  static const String _activitiesPath = '/api/v1/activities';
  static const String _followsPath = '/api/v1/follows';
  static const String _metricsSummaryPath = '/api/v1/metrics/summary';
  static const String _dummyTrainingPathAssetPath =
      'assets/geojson/dummy-training-path.geojson';

  @override
  Future<List<ActivityDto>> listActivities({String scope = 'following'}) async {
    try {
      // Current backend source-of-truth uses /api/v1/activities.
      final response = await _dio.get(
        _activitiesPath,
        queryParameters: {'scope': scope},
      );
      final data = response.data;

      if (data is! List) {
        throw const FormatException('Expected a list of activities');
      }

      return data
          .map(
            (item) =>
                ActivityDto.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  @override
  Future<ActivityDto> createActivity(CreateActivityRequestDto request) async {
    try {
      final payload = request.toJson();

      // GPS is not available yet, so we store a default route for each activity
      // when caller does not pass route_geojson explicitly.
      payload['route_geojson'] ??= await _resolveRouteGeoJson(
        request.routeGeoJson,
      );

      final response = await _dio.post(_activitiesPath, data: payload);

      return ActivityDto.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  @override
  Future<ActivityDto> getActivityById(String id) async {
    final safeId = Uri.encodeComponent(id.trim());

    try {
      final response = await _dio.get('$_activitiesPath/$safeId');
      return ActivityDto.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  @override
  Future<ActivityDto> likeActivity(String id) async {
    final safeId = Uri.encodeComponent(id.trim());

    try {
      final response = await _dio.patch('$_activitiesPath/$safeId/like');
      return ActivityDto.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  @override
  Future<void> followUser(String userId) async {
    final safeUserId = Uri.encodeComponent(userId.trim());
    try {
      await _dio.put('$_followsPath/$safeUserId');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  @override
  Future<void> unfollowUser(String userId) async {
    final safeUserId = Uri.encodeComponent(userId.trim());
    try {
      await _dio.delete('$_followsPath/$safeUserId');
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  @override
  Future<List<FollowSuggestionDto>> listFollowSuggestions({
    int limit = 5,
  }) async {
    try {
      final response = await _dio.get(
        '$_followsPath/suggestions',
        queryParameters: {'limit': limit},
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException('Expected follow suggestions response object');
      }

      final items = (Map<String, dynamic>.from(data))['items'];
      if (items is! List) {
        throw const FormatException('Expected follow suggestions list');
      }

      return items
          .map(
            (item) => FollowSuggestionDto.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  @override
  Future<MetricsSummaryDto> getMetricsSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get(
        _metricsSummaryPath,
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );

      return MetricsSummaryDto.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<Object?> _resolveRouteGeoJson(Object? explicitRouteGeoJson) async {
    if (explicitRouteGeoJson != null) {
      return explicitRouteGeoJson;
    }
    if (_cachedDefaultRouteGeoJson != null) {
      return _cachedDefaultRouteGeoJson;
    }

    final defaultRouteGeoJson = await _loadDefaultRouteGeoJson();
    _cachedDefaultRouteGeoJson = defaultRouteGeoJson;
    return defaultRouteGeoJson;
  }

  static Future<Object?> _loadDummyTrainingPathGeoJson() async {
    final rawGeoJson = await rootBundle.loadString(_dummyTrainingPathAssetPath);
    return jsonDecode(rawGeoJson);
  }
}
