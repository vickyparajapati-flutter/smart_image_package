/// Built-in placeholder styles shown while an image is loading.
///
/// Override the placeholder entirely with `SmartImage.loadingBuilder` when
/// [LoaderType.custom] is selected, or globally via `SmartImageTheme`.
enum LoaderType {
  /// A centered [CircularProgressIndicator]. When download progress is known
  /// it becomes determinate.
  circular,

  /// An animated shimmer sweep across a placeholder block. Ideal for content
  /// cards and avatars.
  shimmer,

  /// A static, theme-aware skeleton block (no animation) — the cheapest
  /// placeholder for long lists.
  skeleton,

  /// Defer entirely to a developer-supplied `loadingBuilder`.
  custom,
}
