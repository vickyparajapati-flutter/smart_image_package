/// Relative scheduling priority for an image fetch.
///
/// The network layer uses priority to order its download queue: higher
/// priorities jump ahead of lower ones, so above-the-fold or hero imagery can
/// be requested with [ImagePriority.high] / [ImagePriority.critical] while
/// off-screen thumbnails default to [ImagePriority.normal].
enum ImagePriority {
  /// Lowest priority. Suitable for far off-screen or decorative imagery.
  low,

  /// Default priority for ordinary imagery.
  normal,

  /// Elevated priority for visible, important imagery.
  high,

  /// Highest priority. Bypasses the queue ordering and starts immediately.
  critical;

  /// Numeric weight used by the download scheduler. Higher wins.
  int get weight => switch (this) {
        ImagePriority.low => 0,
        ImagePriority.normal => 10,
        ImagePriority.high => 20,
        ImagePriority.critical => 30,
      };
}
