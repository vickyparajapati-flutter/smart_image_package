import 'package:flutter/foundation.dart';

import '../enums/loader_type.dart';
import '../enums/transition_type.dart';
import 'cache_config.dart';
import 'retry_config.dart';

/// Verbosity of SmartImageX's internal diagnostic logging.
enum SmartImageLogLevel {
  /// No logging.
  none,

  /// Errors only.
  error,

  /// Errors and warnings.
  warning,

  /// Errors, warnings and lifecycle info.
  info,

  /// Everything, including per-request cache/network traces.
  verbose,
}

/// Process-wide defaults applied to every [SmartImage] unless overridden at the
/// widget level.
///
/// Configure once at startup:
///
/// ```dart
/// void main() {
///   SmartImageConfig.configure(
///     const SmartImageConfig(
///       cache: CacheConfig(maxMemoryBytes: 64 * 1024 * 1024),
///       defaultRetry: RetryConfig(maxAttempts: 5),
///     ),
///   );
///   runApp(const MyApp());
/// }
/// ```
@immutable
class SmartImageConfig {
  /// Creates an immutable configuration. Prefer [SmartImageConfig.configure]
  /// to install it globally.
  const SmartImageConfig({
    this.cache = const CacheConfig(),
    this.defaultRetry = const RetryConfig(),
    this.defaultLoaderType = LoaderType.shimmer,
    this.defaultTransition = TransitionType.fade,
    this.defaultTransitionDuration = const Duration(milliseconds: 300),
    this.adaptiveQualityByDefault = false,
    this.allowedDomains,
    this.logLevel = SmartImageLogLevel.error,
    this.maxConcurrentDownloads = 6,
    this.networkTimeout = const Duration(seconds: 30),
  });

  /// Cache tuning parameters.
  final CacheConfig cache;

  /// Default retry policy for remote fetches.
  final RetryConfig defaultRetry;

  /// Default placeholder style.
  final LoaderType defaultLoaderType;

  /// Default placeholder→image transition.
  final TransitionType defaultTransition;

  /// Default transition duration.
  final Duration defaultTransitionDuration;

  /// Whether the adaptive-quality engine is on by default.
  final bool adaptiveQualityByDefault;

  /// Optional global host whitelist. When non-null, network images whose host
  /// is absent from this list are rejected with a blocked-domain error.
  final List<String>? allowedDomains;

  /// Diagnostic logging verbosity.
  final SmartImageLogLevel logLevel;

  /// Maximum simultaneous network downloads; further requests queue by
  /// priority.
  final int maxConcurrentDownloads;

  /// Per-request network timeout.
  final Duration networkTimeout;

  /// The currently-installed global configuration.
  static SmartImageConfig get instance => _instance;
  static SmartImageConfig _instance = const SmartImageConfig();

  /// Installs [config] as the process-wide default.
  static void configure(SmartImageConfig config) => _instance = config;

  /// Resets the global configuration back to library defaults. Primarily for
  /// tests.
  static void reset() => _instance = const SmartImageConfig();

  /// Returns a copy with selected fields overridden.
  SmartImageConfig copyWith({
    CacheConfig? cache,
    RetryConfig? defaultRetry,
    LoaderType? defaultLoaderType,
    TransitionType? defaultTransition,
    Duration? defaultTransitionDuration,
    bool? adaptiveQualityByDefault,
    List<String>? allowedDomains,
    SmartImageLogLevel? logLevel,
    int? maxConcurrentDownloads,
    Duration? networkTimeout,
  }) =>
      SmartImageConfig(
        cache: cache ?? this.cache,
        defaultRetry: defaultRetry ?? this.defaultRetry,
        defaultLoaderType: defaultLoaderType ?? this.defaultLoaderType,
        defaultTransition: defaultTransition ?? this.defaultTransition,
        defaultTransitionDuration:
            defaultTransitionDuration ?? this.defaultTransitionDuration,
        adaptiveQualityByDefault:
            adaptiveQualityByDefault ?? this.adaptiveQualityByDefault,
        allowedDomains: allowedDomains ?? this.allowedDomains,
        logLevel: logLevel ?? this.logLevel,
        maxConcurrentDownloads:
            maxConcurrentDownloads ?? this.maxConcurrentDownloads,
        networkTimeout: networkTimeout ?? this.networkTimeout,
      );
}
