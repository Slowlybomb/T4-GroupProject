import 'package:dio/dio.dart';

enum ApiErrorType {
  badRequest,
  unauthorized,
  notFound,
  server,
  network,
  unknown,
}

class ApiError implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;

  const ApiError({required this.type, required this.message, this.statusCode});

  factory ApiError.fromDioException(DioException exception) {
    final statusCode = exception.response?.statusCode;

    if (_isNetworkException(exception)) {
      return ApiError(
        type: ApiErrorType.network,
        message: exception.message ?? 'Network error',
        statusCode: statusCode,
      );
    }

    final responseMessage = _extractResponseMessage(exception.response?.data);
    final fallbackMessage = exception.message ?? 'Request failed';
    final message = responseMessage.isEmpty ? fallbackMessage : responseMessage;

    switch (statusCode) {
      case 400:
        return ApiError(
          type: ApiErrorType.badRequest,
          message: message,
          statusCode: statusCode,
        );
      case 401:
        return ApiError(
          type: ApiErrorType.unauthorized,
          message: message,
          statusCode: statusCode,
        );
      case 404:
        return ApiError(
          type: ApiErrorType.notFound,
          message: message,
          statusCode: statusCode,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ApiError(
          type: ApiErrorType.server,
          message: message,
          statusCode: statusCode,
        );
      default:
        return ApiError(
          type: ApiErrorType.unknown,
          message: message,
          statusCode: statusCode,
        );
    }
  }

  static bool _isNetworkException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.unknown:
        return exception.response == null;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
        return false;
    }
  }

  static String _extractResponseMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final error = data['error']?.toString().trim() ?? '';
      final details = data['details']?.toString().trim() ?? '';

      if (error.isNotEmpty && details.isNotEmpty) {
        return '$error: $details';
      }
      if (error.isNotEmpty) {
        return error;
      }
      if (details.isNotEmpty) {
        return details;
      }
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      return _extractResponseMessage(map);
    }

    if (data is String) {
      return data.trim();
    }

    return '';
  }

  @override
  String toString() {
    return 'ApiError(type: $type, statusCode: $statusCode, message: $message)';
  }
}
