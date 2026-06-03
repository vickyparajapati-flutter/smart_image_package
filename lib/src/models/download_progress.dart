/// Progress of an in-flight network download, delivered to `onProgress`.
class DownloadProgress {
  /// Creates a progress event.
  const DownloadProgress({
    required this.received,
    required this.total,
  });

  /// Bytes received so far.
  final int received;

  /// Total bytes expected, or `-1` when the server sent no `Content-Length`.
  final int total;

  /// Whether the total size is known.
  bool get isDeterminate => total > 0;

  /// Completion fraction in `0.0..1.0`, or `null` when indeterminate.
  double? get fraction =>
      isDeterminate ? (received / total).clamp(0.0, 1.0) : null;

  /// Completion as an integer percentage `0..100`, or `null` when
  /// indeterminate. Matches the `onProgress(0 → 100)` contract in the spec.
  int? get percent => isDeterminate ? (fraction! * 100).round() : null;

  @override
  String toString() =>
      'DownloadProgress($received/${isDeterminate ? total : '?'})';
}
