import 'package:flutter/material.dart';

import '../models/smart_image_exception.dart';

/// The default error placeholder, shown when loading fails terminally and the
/// developer supplied neither an `errorBuilder` nor a fallback.
///
/// Theme-aware and, when [onRetry] is provided, offers a manual retry affordance
/// satisfying the "Manual Retry Button" requirement.
class DefaultErrorWidget extends StatelessWidget {
  /// Creates the default error widget.
  const DefaultErrorWidget({
    this.error,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  /// The failure that occurred, if known.
  final SmartImageException? error;

  /// Invoked when the user taps the retry affordance. When `null`, no retry
  /// button is shown.
  final VoidCallback? onRetry;

  /// Renders a minimal icon-only variant for very small targets (e.g. avatars).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = scheme.onSurfaceVariant;

    if (compact) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: iconColor, size: 20),
        ),
      );
    }

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: iconColor, size: 32),
            const SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: iconColor),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A fallback rendering an [IconData] centered on a neutral background, used as
/// the penultimate step of the fallback chain.
class FallbackIcon extends StatelessWidget {
  /// Creates a fallback icon widget.
  const FallbackIcon({required this.icon, this.size, super.key});

  /// The icon to render.
  final IconData icon;

  /// Optional icon size.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, color: scheme.onSurfaceVariant, size: size),
      ),
    );
  }
}
