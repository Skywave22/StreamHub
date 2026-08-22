import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import 'cache_store.dart';

/// A single HTTP response, decoupled from Dio so callers never depend on the
/// transport library directly.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.bodyBytes,
    this.headers = const {},
    this.fromCache = false,
    this.finalUrl,
  });

  final int statusCode;
  final List<int> bodyBytes;
  final Map<String, List<String>> headers;
  final bool fromCache;
  final String? finalUrl;

  bool get isOk => statusCode >= 200 && statusCode < 300;

  String get bodyString => utf8.decode(bodyBytes, allowMalformed: true);

  Map<String, dynamic>? get json {
    try {
      final d = jsonDecode(bodyString);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }
}

/// Result of a manual redirect resolution (redirects not followed).
class RedirectResult {
  const RedirectResult({required this.found, this.location, this.statusCode});
  final bool found;
  final String? location;
  final int? statusCode;
}

/// Raised for non-2xx responses that the caller asked to treat as errors.
class HttpException extends AppException {
  HttpException(
    this.statusCode, {
    required String message,
    AppErrorKind kind = AppErrorKind.network,
    String? technical,
  }) : super(kind, message: message, technical: technical);

  final int statusCode;
}

/// Result of a lightweight reachability probe for a media URL.
class ProbeResult {
  const ProbeResult({required this.reachable, this.statusCode, this.contentType, this.contentLength});
  final bool reachable;
  final int? statusCode;
  final String? contentType;
  final int? contentLength;
}

/// Shared networking layer: HTTPS-only, timeouts, retries with exponential
/// backoff + jitter, request deduplication, cancellation and redacted debug
/// logging (secrets such as `api_key` are never written to logs).
class ApiClient {
  ApiClient({
    Dio? dio,
    CacheStore? cache,
    this.maxRetries = 3,
    this.debugLogging = false,
    this.baseDelay = const Duration(milliseconds: 350),
  })  : _dio = dio ?? _buildDio(),
        _cache = cache;

  final Dio _dio;
  final CacheStore? _cache;
  final int maxRetries;
  final bool debugLogging;
  final Duration baseDelay;
  final Map<String, Future<ApiResponse>> _inflight = {};

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 10),
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 600,
          headers: const {
            'User-Agent': 'StreamHub/1.0 (+https://github.com/Skywave22/StreamHub)',
            'Accept': 'application/json, */*',
          },
        ),
      );

  Future<ApiResponse> get(
    String url, {
    Map<String, String>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    Duration? cacheTtl,
  }) {
    return _dedup('GET', url, query, () => _perform('GET', url,
        query: query, headers: headers, cancelToken: cancelToken, cacheTtl: cacheTtl));
  }

  Future<ApiResponse> head(
    String url, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) {
    return _dedup('HEAD', url, null, () => _perform('HEAD', url,
        headers: headers, cancelToken: cancelToken, cacheTtl: null));
  }

  /// Performs a GET without following redirects and returns the `Location`
  /// header when a 3xx is received. Used to resolve provider short codes
  /// (e.g. URL-shortener based SkyStream short codes).
  Future<RedirectResult> resolveRedirect(String url, {CancelToken? cancelToken}) async {
    try {
      final resp = await _dio.request<List<int>>(
        url,
        options: Options(
          method: 'GET',
          followRedirects: false,
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 600,
          headers: const {'User-Agent': 'StreamHub/1.0'},
        ),
        cancelToken: cancelToken,
      );
      final status = resp.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final loc = resp.headers.value('location');
        return RedirectResult(found: loc != null && loc.isNotEmpty, location: loc, statusCode: status);
      }
      return RedirectResult(found: false, statusCode: status);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw _mapDioError(e);
    }
  }

  /// Probes whether a URL is actually reachable and returns metadata. Used to
  /// verify sources before claiming they are playable.
  Future<ProbeResult> probe(String url, {CancelToken? cancelToken}) async {
    try {
      final resp = await _perform('HEAD', url, headers: null, cancelToken: cancelToken, cacheTtl: null);
      if (resp.statusCode < 400) {
        return ProbeResult(
          reachable: true,
          statusCode: resp.statusCode,
          contentType: _first(resp.headers['content-type']),
          contentLength: int.tryParse(_first(resp.headers['content-length']) ?? ''),
        );
      }
    } on AppException {
      // fall through to a ranged GET probe
    }
    // Some servers reject HEAD; try a minimal ranged GET.
    try {
      final resp = await _perform('GET', url,
          headers: const {'Range': 'bytes=0-0'}, cancelToken: cancelToken, cacheTtl: null);
      if (resp.statusCode == 206 || (resp.statusCode >= 200 && resp.statusCode < 400)) {
        return ProbeResult(
          reachable: true,
          statusCode: resp.statusCode,
          contentType: _first(resp.headers['content-type']),
          contentLength: int.tryParse(_first(resp.headers['content-length']) ?? ''),
        );
      }
    } on AppException {
      // ignore
    }
    return const ProbeResult(reachable: false);
  }

  Future<ApiResponse> _dedup(
    String method,
    String url,
    Map<String, String>? query,
    Future<ApiResponse> Function() run,
  ) async {
    final key = '$method ${_keyedUrl(url, query)}';
    final existing = _inflight[key];
    if (existing != null) return existing;
    final future = run();
    _inflight[key] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(key);
    }
  }

  Future<ApiResponse> _perform(
    String method,
    String url, {
    Map<String, String>? query,
    Map<String, String>? headers,
    CancelToken? cancelToken,
    Duration? cacheTtl,
  }) async {
    if (method == 'GET' && cacheTtl != null && _cache != null) {
      final cached = await _cache.getBytes(_keyedUrl(url, query));
      if (cached != null) {
        _log(method, url, 200, fromCache: true);
        return ApiResponse(statusCode: 200, bodyBytes: cached.bytes, fromCache: true);
      }
    }

    var delay = baseDelay;
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final resp = await _dio.request<List<int>>(
          url,
          options: Options(
            method: method,
            headers: headers,
            validateStatus: (s) => s != null && s < 600,
            responseType: ResponseType.bytes,
          ),
          queryParameters: query,
          cancelToken: cancelToken,
        );
        final status = resp.statusCode ?? 0;
        _log(method, url, status, fromCache: false);
        final body = resp.data ?? <int>[];
        final apiResp = ApiResponse(
          statusCode: status,
          bodyBytes: body,
          headers: _flatten(resp.headers),
          finalUrl: resp.realUri.toString(),
        );
        if (apiResp.isOk || (method == 'HEAD' && status < 400)) {
          if (method == 'GET' && cacheTtl != null && _cache != null) {
            await _cache.putBytes(_keyedUrl(url, query), body, ttl: cacheTtl);
          }
          return apiResp;
        }
        final shouldRetry = _shouldRetryStatus(status) && attempt < maxRetries;
        if (!shouldRetry) {
          throw HttpException(status, message: 'Request failed with status $status.', technical: url);
        }
        lastError = HttpException(status, message: 'Request failed with status $status.', technical: url);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        lastError = e;
        if (!_isRetryable(e) || attempt >= maxRetries) {
          throw _mapDioError(e);
        }
      }
      await Future<void>.delayed(delay);
      final jitter = Duration(milliseconds: Random().nextInt(120));
      delay = delay * 2 + jitter;
    }
    if (lastError is AppException) throw lastError;
    throw AppException(AppErrorKind.unknown, message: 'Request failed.', technical: url);
  }

  bool _shouldRetryStatus(int status) => status == 429 || status >= 500;

  bool _isRetryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  AppException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(AppErrorKind.timeout, message: 'The request timed out.', technical: e.message);
      case DioExceptionType.cancel:
        return const CancelledException();
      default:
        return AppException(AppErrorKind.network, message: 'Unable to connect to provider.', technical: e.message);
    }
  }

  void _log(String method, String url, int status, {bool fromCache = false}) {
    if (!debugLogging) return;
    final u = Uri.tryParse(url);
    final host = u?.host ?? '?';
    final path = u?.path ?? '';
    // Deliberately omit the query string so secrets are never logged.
    // ignore: avoid_print
    print('[HTTP] $method $host$path -> $status${fromCache ? ' (cache)' : ''}');
  }

  static String _keyedUrl(String url, Map<String, String>? query) {
    if (query == null || query.isEmpty) return url;
    final keys = query.keys.toList()..sort();
    final q = keys.map((k) => '$k=${query[k]}').join('&');
    return '$url?$q';
  }

  static Map<String, List<String>> _flatten(Headers h) {
    final out = <String, List<String>>{};
    h.forEach((k, v) => out[k.toLowerCase()] = v.map((e) => e.toString()).toList());
    return out;
  }

  static String? _first(List<String>? v) => (v == null || v.isEmpty) ? null : v.first;
}
