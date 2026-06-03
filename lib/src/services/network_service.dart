import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../enums/image_priority.dart';
import '../models/download_progress.dart';
import '../models/smart_image_config.dart';
import '../models/smart_image_exception.dart';
import '../utils/domain_guard.dart';
import '../utils/logger.dart';

/// The successful result of a network fetch: the payload plus the server's
/// declared content type (used as a secondary signal by the format detector).
class NetworkResponse {
  /// Wraps the fetched [bytes] and optional [mimeType].
  const NetworkResponse(this.bytes, this.mimeType);

  /// The downloaded payload.
  final Uint8List bytes;

  /// The `Content-Type` header, if the server sent one.
  final String? mimeType;
}

/// Downloads remote image bytes with per-request progress, a priority-ordered
/// queue and a global concurrency cap.
///
/// Requests beyond [SmartImageConfig.maxConcurrentDownloads] are parked in a
/// priority queue; when a slot frees up the highest-priority waiter starts.
/// This keeps a screen full of images from saturating the connection while
/// still letting a [ImagePriority.critical] hero jump the line.
class NetworkService {
  /// Creates a service. Inject an [http.Client] in tests.
  NetworkService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final List<_QueuedRequest> _queue = <_QueuedRequest>[];
  int _activeCount = 0;

  static NetworkService? _instance;

  /// The shared instance.
  static NetworkService get instance => _instance ??= NetworkService();

  /// Test seam: replaces the shared instance.
  static set debugInstance(NetworkService service) => _instance = service;

  /// Fetches [uri], honouring the configured domain whitelist, timeout, and
  /// concurrency limits.
  ///
  /// Reports byte-level progress through [onProgress]. Throws a
  /// [SmartImageException] on a blocked domain, non-2xx status, timeout, or
  /// transport error — categorised so the retry engine can decide whether to
  /// retry.
  Future<NetworkResponse> fetch(
    Uri uri, {
    ImagePriority priority = ImagePriority.normal,
    void Function(DownloadProgress)? onProgress,
    Duration? timeout,
  }) async {
    final config = SmartImageConfig.instance;
    if (!DomainGuard.isAllowed(uri, config.allowedDomains)) {
      throw SmartImageException(
        SmartImageErrorType.blockedDomain,
        'Host "${uri.host}" is not in allowedDomains.',
      );
    }

    final completer = Completer<NetworkResponse>();
    final request = _QueuedRequest(
      uri: uri,
      priority: priority,
      onProgress: onProgress,
      timeout: timeout ?? config.networkTimeout,
      completer: completer,
    );
    _enqueue(request);
    return completer.future;
  }

  void _enqueue(_QueuedRequest request) {
    _queue.add(request);
    // Stable, priority-descending order: higher weight first, FIFO within a
    // priority band.
    _queue.sort((a, b) {
      final byPriority = b.priority.weight.compareTo(a.priority.weight);
      if (byPriority != 0) return byPriority;
      return a.seq.compareTo(b.seq);
    });
    _pump();
  }

  void _pump() {
    final maxConcurrent = SmartImageConfig.instance.maxConcurrentDownloads;
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      _activeCount++;
      unawaited(
        _run(request).whenComplete(() {
          _activeCount--;
          _pump();
        }),
      );
    }
  }

  Future<void> _run(_QueuedRequest request) async {
    try {
      final result = await _download(request).timeout(
        request.timeout,
        onTimeout: () => throw SmartImageException(
          SmartImageErrorType.network,
          'Request to ${request.uri} timed out after '
          '${request.timeout.inSeconds}s.',
        ),
      );
      if (!request.completer.isCompleted) request.completer.complete(result);
    } catch (error, stack) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(_normalize(error, stack), stack);
      }
    }
  }

  Future<NetworkResponse> _download(_QueuedRequest request) async {
    SmartLogger.verbose(() => 'GET ${request.uri} [${request.priority.name}]');
    final httpRequest = http.Request('GET', request.uri);
    final response = await _client.send(httpRequest);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Drain to release the socket.
      unawaited(response.stream.drain<void>());
      throw SmartImageException(
        SmartImageErrorType.httpStatus,
        'Server returned ${response.statusCode} for ${request.uri}.',
        statusCode: response.statusCode,
      );
    }

    final total = response.contentLength ?? -1;
    final builder = BytesBuilder(copy: false);
    var received = 0;

    await for (final chunk in response.stream) {
      builder.add(chunk);
      received += chunk.length;
      request.onProgress?.call(
        DownloadProgress(received: received, total: total),
      );
    }

    return NetworkResponse(
      builder.takeBytes(),
      response.headers['content-type'],
    );
  }

  SmartImageException _normalize(Object error, StackTrace stack) {
    if (error is SmartImageException) return error;
    return SmartImageException(
      SmartImageErrorType.network,
      error.toString(),
      cause: error,
      stackTrace: stack,
    );
  }

  /// Closes the underlying client. Call on app shutdown if you constructed a
  /// dedicated instance.
  void dispose() => _client.close();
}

/// Internal record for a queued download.
class _QueuedRequest {
  _QueuedRequest({
    required this.uri,
    required this.priority,
    required this.onProgress,
    required this.timeout,
    required this.completer,
  }) : seq = _counter++;

  static int _counter = 0;

  final Uri uri;
  final ImagePriority priority;
  final void Function(DownloadProgress)? onProgress;
  final Duration timeout;
  final Completer<NetworkResponse> completer;

  /// Monotonic sequence for stable FIFO ordering within a priority band.
  final int seq;
}
