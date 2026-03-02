import 'package:dio/dio.dart';

import '../config/runtime_config.dart';
import 'auth_interceptor.dart';
import 'auth_token_provider.dart';

class ApiClient {
  final Dio dio;

  ApiClient._(this.dio);

  factory ApiClient.create({
    required RuntimeConfig config,
    required AuthTokenProvider authTokenProvider,
  }) {
    // One shared Dio instance for all API repositories.
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Auth header handling is centralized in interceptor logic.
    dio.interceptors.add(AuthInterceptor(authTokenProvider));

    return ApiClient._(dio);
  }
}
