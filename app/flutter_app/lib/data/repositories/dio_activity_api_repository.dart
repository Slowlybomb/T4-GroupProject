import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/activity_dto.dart';
import '../models/create_activity_request_dto.dart';
import 'activity_api_repository.dart';

class DioActivityApiRepository implements ActivityApiRepository {
  DioActivityApiRepository(this._dio);

  final Dio _dio;

  static const String _activitiesPath = '/api/v1/activities';

  @override
  Future<List<ActivityDto>> listActivities() async {
    try {
      // Current backend source-of-truth uses /api/v1/activities.
      final response = await _dio.get(_activitiesPath);
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
      final response = await _dio.post(_activitiesPath, data: request.toJson());

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
}
