import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../enums/transition_type.dart' show ConnectionQuality;
import '../utils/logger.dart';

/// Reports the current [ConnectionQuality] for the adaptive-quality engine.
///
/// Quality is inferred from the active connection type: cellular/other links
/// are treated as [ConnectionQuality.slow] (favouring compressed variants),
/// Wi-Fi/ethernet as [ConnectionQuality.fast], and no connectivity as
/// [ConnectionQuality.offline].
///
/// This intentionally avoids active bandwidth probing — measuring throughput
/// would itself consume the data we are trying to conserve. The heuristic is a
/// good-enough proxy and updates live as connectivity changes.
class ConnectivityService {
  /// Creates a service. Inject a [Connectivity] for testing.
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectionQuality _quality = ConnectionQuality.unknown;
  bool _started = false;

  static ConnectivityService? _instance;

  /// The shared instance.
  static ConnectivityService get instance =>
      _instance ??= ConnectivityService();

  /// Test seam: replaces the shared instance.
  static set debugInstance(ConnectivityService service) => _instance = service;

  /// The most recently observed quality.
  ConnectionQuality get quality => _quality;

  /// Begins listening for connectivity changes. Safe to call repeatedly.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _quality = _classify(await _connectivity.checkConnectivity());
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        _quality = _classify(results);
        SmartLogger.verbose(() => 'Connectivity → ${_quality.name}');
      });
    } catch (error) {
      SmartLogger.warning('Connectivity probe failed: $error');
      _quality = ConnectionQuality.unknown;
    }
  }

  /// Probes connectivity once without subscribing, returning the quality.
  Future<ConnectionQuality> probe() async {
    try {
      _quality = _classify(await _connectivity.checkConnectivity());
    } catch (_) {
      _quality = ConnectionQuality.unknown;
    }
    return _quality;
  }

  ConnectionQuality _classify(List<ConnectivityResult> results) =>
      classify(results);

  /// Maps raw connectivity results to a [ConnectionQuality] bucket.
  ///
  /// Exposed for testing; this is the pure heart of the adaptive-quality
  /// heuristic and carries no platform dependency.
  @visibleForTesting
  static ConnectionQuality classify(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectionQuality.offline;
    }
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return ConnectionQuality.fast;
    }
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.bluetooth)) {
      return ConnectionQuality.slow;
    }
    // vpn / other → assume usable.
    return ConnectionQuality.fast;
  }

  /// Releases the change subscription.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
