import 'package:flutter/material.dart';
import 'package:smart_image_x/smart_image_x.dart';

void main() {
  // Configure SmartImageX once at startup (entirely optional).
  SmartImageConfig.configure(
    const SmartImageConfig(
      cache: CacheConfig(maxMemoryBytes: 64 * 1024 * 1024),
      defaultRetry: RetryConfig(maxAttempts: 3),
      logLevel: SmartImageLogLevel.info,
    ),
  );
  runApp(const ExampleApp());
}

/// Root of the demo application.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartImageX',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

const _demoOne = 'https://picsum.photos/id/1015/600/400';
const _demoTwo = 'https://picsum.photos/id/1025/600/400';
const _demoThree = 'https://picsum.photos/id/1003/600/400';
const _demoFour = 'https://picsum.photos/id/1044/600/400';

const _demos = <String>[_demoOne, _demoTwo, _demoThree, _demoFour];

/// A tabbed gallery of the package's headline capabilities.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SmartImageX'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Basics'),
              Tab(text: 'Shapes & States'),
              Tab(text: 'Gallery & Zoom'),
              Tab(text: 'Cache'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BasicsTab(),
            _ShapesTab(),
            _GalleryTab(),
            _CacheTab(),
          ],
        ),
      ),
    );
  }
}

class _BasicsTab extends StatelessWidget {
  const _BasicsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SectionTitle('The simplest possible usage'),
        AspectRatio(
          aspectRatio: 3 / 2,
          child: SmartImage(image: _demoOne),
        ),
        SizedBox(height: 24),
        _SectionTitle('Progressive load with a BlurHash placeholder'),
        AspectRatio(
          aspectRatio: 3 / 2,
          child: SmartImage(
            image: 'https://picsum.photos/id/1062/800/600',
            blurHash: r'L6PZfSi_.AyE_3t7t7R**0o#DgR4',
          ),
        ),
        SizedBox(height: 24),
        _SectionTitle('Inline SVG, auto-detected'),
        SizedBox(
          height: 120,
          child: SmartImage(
            image:
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
                '<circle cx="50" cy="50" r="45" fill="#6750A4"/>'
                '<path d="M30 52l14 14 26-30" stroke="white" stroke-width="8" '
                'fill="none"/></svg>',
          ),
        ),
        SizedBox(height: 24),
        _SectionTitle('Bundled SVG asset (path auto-detected)'),
        SizedBox(height: 120, child: SmartImage(image: 'assets/logo.svg')),
      ],
    );
  }
}

class _ShapesTab extends StatelessWidget {
  const _ShapesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Circle avatar'),
        const Center(
          child: SmartImage(
            image: _demoTwo,
            width: 120,
            height: 120,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Rounded rectangle + grayscale'),
        Center(
          child: SmartImage(
            image: _demoThree,
            width: 200,
            height: 140,
            borderRadius: BorderRadius.circular(16),
            grayscale: true,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Error → fallback icon'),
        const Center(
          child: SmartImage(
            image: 'https://invalid.example.invalid/missing.png',
            width: 120,
            height: 120,
            retryCount: 1,
            fallbackIcon: Icons.image_not_supported,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Error → fallback to a bundled asset'),
        const Center(
          child: SmartImage(
            image: 'https://invalid.example.invalid/avatar.png',
            width: 120,
            height: 120,
            shape: BoxShape.circle,
            retryCount: 0,
            fallbackImage: 'assets/avatar_placeholder.svg',
          ),
        ),
      ],
    );
  }
}

class _GalleryTab extends StatelessWidget {
  const _GalleryTab();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _demos.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => SmartImageGallery.open(
            context,
            images: _demos,
            initialIndex: index,
            heroTagBuilder: (i) => 'gallery-$i',
          ),
          child: Hero(
            tag: 'gallery-$index',
            child: SmartImage(
              image: _demos[index],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

class _CacheTab extends StatefulWidget {
  const _CacheTab();

  @override
  State<_CacheTab> createState() => _CacheTabState();
}

class _CacheTabState extends State<_CacheTab> {
  CacheStats? _stats;

  Future<void> _refresh() async {
    final stats = await SmartImage.cacheStats();
    if (mounted) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats != null) ...[
            _StatRow('Memory', '${stats.memoryCacheSizeMb.toStringAsFixed(2)} MB '
                '(${stats.memoryEntryCount} entries)'),
            _StatRow('Disk', '${stats.diskCacheSizeMb.toStringAsFixed(2)} MB '
                '(${stats.diskFileCount} files)'),
            _StatRow('Hit rate', '${(stats.hitRate * 100).toStringAsFixed(1)}%'),
            _StatRow('Hits / Misses', '${stats.hitCount} / ${stats.missCount}'),
          ] else
            const Text('Tap "Refresh stats" to read the cache.'),
          const Spacer(),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Refresh stats'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => SmartImage.preloadAll(_demos),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Preload all demo images'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await SmartImage.clearCache();
              await _refresh();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear cache'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
