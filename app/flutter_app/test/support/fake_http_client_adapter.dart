import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class StubResponse {
  final int statusCode;
  final Object? data;
  final Map<String, List<String>> headers;

  const StubResponse({
    required this.statusCode,
    this.data,
    this.headers = const {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  });
}

class FakeHttpClientAdapter implements HttpClientAdapter {
  final Map<String, StubResponse> stubs;
  final List<RequestOptions> requests = <RequestOptions>[];

  FakeHttpClientAdapter(this.stubs);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final key =
        '${options.method.toUpperCase()} ${_normalizePath(options.path)}';
    final response =
        stubs[key] ??
        const StubResponse(statusCode: 404, data: {'error': 'Not Found'});

    final body = response.data == null ? '' : jsonEncode(response.data);

    return ResponseBody.fromString(
      body,
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close({bool force = false}) {}

  static String _normalizePath(String path) {
    final uri = Uri.tryParse(path);
    var normalized = uri?.path ?? path;

    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
