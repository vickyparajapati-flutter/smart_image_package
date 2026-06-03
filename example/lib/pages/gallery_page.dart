import 'package:flutter/material.dart';
import 'package:smart_image_x/smart_image_x.dart';

import '../sample_data.dart';
import '../widgets/demo_card.dart';
import '../widgets/source_chip.dart';

/// Demonstrates the interactive viewers: inline zoom, tap-to-fullscreen, and
/// the swipeable gallery — all built on Flutter's own InteractiveViewer (no
/// extra package).
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    const photos = SampleData.networkPhotos;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionIntro(
          title: 'Viewer & gallery',
          subtitle:
              'Pinch-zoom, double-tap, pan, full-screen and a hero-animated '
              'gallery — zero extra dependencies.',
        ),
        const SizedBox(height: 8),

        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Tap-to-open gallery',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const SourceChip(DemoSource.network),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap any thumbnail to open a full-screen, swipeable, zoomable '
                  'gallery with a shared-element hero transition.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => SmartImageGallery.open(
                      context,
                      images: photos,
                      initialIndex: index,
                      heroTagBuilder: (i) => 'gallery-$i',
                    ),
                    child: Hero(
                      tag: 'gallery-$index',
                      child: SmartImage(
                        image: photos[index],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        DemoCard(
          title: 'Inline zoom',
          source: DemoSource.asset,
          preview: PreviewFrame(
            height: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                height: 184,
                width: double.infinity,
                child: SmartImage(
                  image: SampleData.samplePngAsset,
                  enableZoom: true,
                ),
              ),
            ),
          ),
          description:
              'Set enableZoom: true to make an image pinch-/double-tap-zoomable '
              'right where it sits — great for maps, diagrams and receipts. '
              '(Try it: pinch or double-tap.)',
          code: 'SmartImage(image: …, enableZoom: true)',
        ),

        DemoCard(
          title: 'Open viewer on tap',
          source: DemoSource.network,
          preview: PreviewFrame(
            height: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 184,
                width: double.infinity,
                child: SmartImage(
                  image: SampleData.networkPhotos[2],
                  openViewerOnTap: true,
                  heroTag: 'single-viewer',
                ),
              ),
            ),
          ),
          description:
              'openViewerOnTap pushes a full-screen, zoomable viewer with a hero '
              'animation — perfect for thumbnails in a feed.',
          code: 'openViewerOnTap: true, heroTag: "single-viewer"',
        ),
      ],
    );
  }
}
