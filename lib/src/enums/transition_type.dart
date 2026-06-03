/// Animation used when an image swaps from its placeholder to the final frame.
enum TransitionType {
  /// No animation; the image appears immediately.
  none,

  /// The image fades in over `transitionDuration`.
  fade,

  /// The placeholder cross-fades into the image (both visible mid-transition).
  crossFade,

  /// The image scales up from a slightly smaller size while fading in.
  scale,
}

/// Quality buckets reported by the connectivity service and consumed by the
/// adaptive-quality engine.
enum ConnectionQuality {
  /// No usable connectivity.
  offline,

  /// Constrained connection (e.g. 2G/3G or a metered link) — prefer
  /// compressed / thumbnail variants.
  slow,

  /// Healthy connection — fetch full quality.
  fast,

  /// Quality is not yet known (initial state before the first probe).
  unknown;

  /// Whether the adaptive engine should downgrade to a compressed variant.
  bool get prefersLowData =>
      this == ConnectionQuality.slow || this == ConnectionQuality.offline;
}
