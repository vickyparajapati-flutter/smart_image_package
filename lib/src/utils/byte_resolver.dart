import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../cache/cache_manager.dart';
import '../enums/cache_policy.dart';
import '../enums/image_source_type.dart';
import '../models/image_source.dart';
import '../services/network_service.dart';

/// Resolves the raw encoded bytes behind any [ResolvedImageSource], regardless
/// of origin.
///
/// Used by the metadata and preload paths, where the pipeline needs the bytes
/// themselves rather than a renderable [ImageProvider]. Network sources are
/// served from (and written back to) the cache so a subsequent render is free.
class SmartImageBytes {
  const SmartImageBytes._();

  /// Returns the bytes for [source], or `null` if they cannot be obtained.
  static Future<Uint8List?> resolve(
    ResolvedImageSource source, {
    CachePolicy policy = CachePolicy.smart,
  }) async {
    switch (source.type) {
      case ImageSourceType.memory:
      case ImageSourceType.base64:
      case ImageSourceType.svgString:
        return source.bytes;

      case ImageSourceType.asset:
        try {
          final data = await rootBundle.load(source.path!);
          return data.buffer.asUint8List();
        } catch (_) {
          return null;
        }

      case ImageSourceType.file:
        try {
          final file = File(source.path!);
          return file.existsSync() ? await file.readAsBytes() : null;
        } catch (_) {
          return null;
        }

      case ImageSourceType.network:
        final key = source.cacheKey;
        final cached = await CacheManager.instance.read(key, policy);
        if (cached != null) return cached;
        try {
          final response = await NetworkService.instance.fetch(source.uri!);
          await CacheManager.instance.write(key, response.bytes, policy);
          return response.bytes;
        } catch (_) {
          return null;
        }

      case ImageSourceType.unknown:
        return null;
    }
  }
}
