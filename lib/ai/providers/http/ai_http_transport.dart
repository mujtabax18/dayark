import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/ai_cancellation.dart';
import '../../core/ai_error.dart';

/// Resolve credentials at request time; nothing here persists or logs them.
typedef AiCredentialLoader = FutureOr<String?> Function();

class AiHttpTransport {
  AiHttpTransport({required Uri baseUrl, bool allowInsecureHttp = false})
    : baseUrl = _validatedUrl(baseUrl, allowInsecureHttp),
      _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
        ),
      );
  final Uri baseUrl;
  final Dio _dio;
  bool _closed = false;

  static Uri _validatedUrl(Uri uri, bool insecure) {
    final loopback = ['localhost', '127.0.0.1', '::1'].contains(uri.host);
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' && (loopback || insecure)))) {
      throw ArgumentError(
        'Use an HTTPS base URL without credentials, query or fragment. '
        'HTTP requires loopback or explicit allowInsecureHttp.',
      );
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }

  Future<Map<String, dynamic>> send(
    String path, {
    required AiCancellationToken cancellationToken,
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    Map<String, String> headers = const {},
  }) async {
    cancellationToken.throwIfCancelled();
    if (_closed) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'AI provider is closed.',
      );
    }
    final cancel = CancelToken();
    final remove = cancellationToken.onCancel(() => cancel.cancel());
    try {
      final response = await _dio.requestUri<String>(
        baseUrl
            .resolve(path)
            .replace(
              queryParameters: query?.isEmpty == false
                  ? query!.map((key, value) => MapEntry(key, value.toString()))
                  : null,
            ),
        data: body,
        cancelToken: cancel,
        options: Options(
          method: method,
          headers: {'Content-Type': 'application/json', ...headers},
        ),
      );
      cancellationToken.throwIfCancelled();
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) throw _statusError(status);
      final raw = response.data;
      final data = raw == null ? null : jsonDecode(raw);
      if (data is! Map<String, dynamic>) throw invalidAiResponse;
      return data;
    } on AiException {
      rethrow;
    } on DioException catch (error) {
      cancellationToken.throwIfCancelled();
      throw switch (error.type) {
        DioExceptionType.cancel => const AiException(
          AiErrorCode.cancelled,
          'AI request cancelled.',
        ),
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => const AiException(
          AiErrorCode.timeout,
          'AI provider timed out.',
          retryable: true,
        ),
        DioExceptionType.connectionError => const AiException(
          AiErrorCode.network,
          'Unable to connect to AI provider.',
          retryable: true,
        ),
        DioExceptionType.badCertificate => const AiException(
          AiErrorCode.network,
          'AI provider certificate could not be verified.',
        ),
        _ => invalidAiResponse,
      };
    } catch (_) {
      cancellationToken.throwIfCancelled();
      throw invalidAiResponse;
    } finally {
      remove();
    }
  }

  /// Bounded SSE / NDJSON decoding; arbitrary transport chunk boundaries and UTF-8 are supported.
  Stream<Map<String, dynamic>> stream(
    String path, {
    required Map<String, Object?> body,
    required Map<String, String> headers,
    Map<String, String>? query,
    required AiCancellationToken cancellationToken,
    bool ndjson = false,
  }) async* {
    cancellationToken.throwIfCancelled();
    if (_closed) {
      throw const AiException(
        AiErrorCode.providerUnavailable,
        'AI provider is closed.',
      );
    }
    final cancel = CancelToken();
    final remove = cancellationToken.onCancel(() => cancel.cancel());
    try {
      final response = await _dio.postUri<ResponseBody>(
        baseUrl.resolve(path).replace(queryParameters: query),
        data: body,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Content-Type': 'application/json',
            'Accept': ndjson ? 'application/x-ndjson' : 'text/event-stream',
            ...headers,
          },
        ),
      );
      final streamBody = response.data!;
      if ((response.statusCode ?? 0) < 200 || response.statusCode! >= 300) {
        await streamBody.stream.listen(null).cancel();
        throw _statusError(response.statusCode ?? 0);
      }
      var event = StringBuffer();
      // Bound each line before LineSplitter can buffer an unbounded frame.
      var lineLength = 0;
      final decoded = streamBody.stream
          .map((chunk) {
            for (final byte in chunk) {
              lineLength = byte == 10 ? 0 : lineLength + 1;
              if (lineLength > 1024 * 1024) throw invalidAiResponse;
            }
            return chunk;
          })
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in decoded) {
        cancellationToken.throwIfCancelled();
        if (ndjson) {
          if (line.trim().isNotEmpty) yield aiObject(jsonDecode(line));
        } else if (line.isEmpty) {
          if (event.isNotEmpty) {
            final value = event.toString().trimRight();
            event = StringBuffer();
            if (value == '[DONE]') {
              yield {'_done': true};
              return;
            }
            yield aiObject(jsonDecode(value));
          }
        } else if (line.startsWith('data:')) {
          event.writeln(line.substring(5).trimLeft());
          if (event.length > 1024 * 1024) throw invalidAiResponse;
        }
      }
      if (!ndjson && event.isNotEmpty) throw invalidAiResponse;
    } on AiException {
      rethrow;
    } on DioException catch (error) {
      cancellationToken.throwIfCancelled();
      throw AiException(
        error.type == DioExceptionType.receiveTimeout
            ? AiErrorCode.timeout
            : AiErrorCode.network,
        'AI stream connection failed. Retry the message.',
      );
    } catch (_) {
      cancellationToken.throwIfCancelled();
      throw invalidAiResponse;
    } finally {
      remove();
      cancel.cancel();
    }
  }

  static AiException _statusError(int status) => switch (status) {
    401 => const AiException(
      AiErrorCode.authentication,
      'AI credentials are missing or invalid.',
    ),
    403 => const AiException(
      AiErrorCode.permissionDenied,
      'AI provider denied access.',
    ),
    404 => const AiException(
      AiErrorCode.providerUnavailable,
      'AI endpoint or model was not found.',
    ),
    408 || 504 => const AiException(
      AiErrorCode.timeout,
      'AI provider timed out.',
      retryable: true,
    ),
    429 => const AiException(
      AiErrorCode.rateLimited,
      'AI provider rate limit reached.',
      retryable: true,
    ),
    >= 500 => const AiException(
      AiErrorCode.network,
      'AI provider is temporarily unavailable.',
      retryable: true,
    ),
    >= 300 && < 400 => const AiException(
      AiErrorCode.invalidRequest,
      'AI endpoint redirects are not allowed.',
    ),
    _ => const AiException(
      AiErrorCode.invalidRequest,
      'AI provider rejected the request.',
    ),
  };

  void close() {
    _closed = true;
    _dio.close(force: true);
  }
}

const invalidAiResponse = AiException(
  AiErrorCode.invalidResponse,
  'AI provider returned an invalid or empty response.',
);

Map<String, dynamic> aiObject(Object? value) {
  if (value is! Map<String, dynamic>) throw invalidAiResponse;
  return value;
}

List<dynamic> aiList(Object? value) {
  if (value is! List) throw invalidAiResponse;
  return value;
}

String aiString(Object? value) {
  if (value is! String || value.trim().isEmpty) throw invalidAiResponse;
  return value;
}

int? aiTokenCount(Object? value) {
  if (value == null) return null;
  if (value is! int || value < 0) throw invalidAiResponse;
  return value;
}
