import 'package:flutter/material.dart';
import 'package:smart_image_x/smart_image_x.dart';

import '../sample_data.dart';
import '../widgets/demo_card.dart';

/// Live view of the two-tier cache: stats, preloading and clearing.
class CachePage extends StatefulWidget {
  const CachePage({super.key});

  @override
  State<CachePage> createState() => _CachePageState();
}

class _CachePageState extends State<CachePage> {
  CacheStats? _stats;
  String _status = 'Tap “Refresh stats” to read the cache.';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final stats = await SmartImage.cacheStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _preload() async {
    setState(() => _status = 'Preloading ${SampleData.networkPhotos.length} images…');
    await SmartImage.preloadAll(SampleData.networkPhotos);
    await _refresh();
    if (mounted) setState(() => _status = 'Preloaded into cache ✓');
  }

  Future<void> _clear() async {
    await SmartImage.clearCache();
    await _refresh();
    if (mounted) setState(() => _status = 'Cache cleared ✓');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _stats;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionIntro(
          title: 'Cache',
          subtitle:
              'Caching is on by default: memory → disk → network. Inspect, '
              'warm and clear it through the static API.',
        ),
        const SizedBox(height: 12),

        if (stats != null)
          Row(
            children: [
              _statTile(context, 'Memory',
                  '${stats.memoryCacheSizeMb.toStringAsFixed(1)} MB',
                  '${stats.memoryEntryCount} entries', Icons.memory),
              const SizedBox(width: 12),
              _statTile(context, 'Disk',
                  '${stats.diskCacheSizeMb.toStringAsFixed(1)} MB',
                  '${stats.diskFileCount} files', Icons.sd_storage_outlined),
            ],
          ),
        const SizedBox(height: 12),
        if (stats != null)
          Row(
            children: [
              _statTile(context, 'Hit rate',
                  '${(stats.hitRate * 100).toStringAsFixed(0)}%',
                  '${stats.hitCount} hits', Icons.bolt_outlined),
              const SizedBox(width: 12),
              _statTile(context, 'Misses', '${stats.missCount}',
                  '${stats.totalLookups} lookups', Icons.search_off_outlined),
            ],
          ),

        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_status, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh stats'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _preload,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Preload demo images'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear cache'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        const DemoCard(
          title: 'How caching works',
          source: null,
          preview: SizedBox.shrink(),
          description:
              'On request: memory (LRU) → disk (TTL + size bounded) → network, '
              'writing back on the way. Disk entries are gzipped when it helps '
              '(a win for SVG, a no-op for already-compressed photos). Choose a '
              'CachePolicy per widget: smart (default), memoryOnly, diskOnly, '
              'refresh or none.',
          code: 'SmartImage(image: url, cachePolicy: CachePolicy.smart)',
        ),
      ],
    );
  }

  Widget _statTile(BuildContext context, String label, String value,
      String sub, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(height: 10),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text(sub,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    )),
          ],
        ),
      ),
    );
  }
}
