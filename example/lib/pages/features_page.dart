import 'package:flutter/material.dart';
import 'package:smart_image_x/smart_image_x.dart';

import '../sample_data.dart';
import '../widgets/demo_card.dart';
import '../widgets/source_chip.dart';

/// Showcases the rendering features layered on top of any source: shapes,
/// placeholders, BlurHash, transforms, transitions and the fallback chain.
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionIntro(
          title: 'Rendering features',
          subtitle:
              'Shapes, placeholders, effects and resilient error handling — all '
              'declared inline on the same widget.',
        ),
        const SizedBox(height: 8),

        DemoCard(
          title: 'Shapes',
          source: DemoSource.asset,
          preview: PreviewFrame(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SmartImage(
                      image: SampleData.samplePngAsset,
                      width: 96,
                      height: 96,
                      shape: BoxShape.circle,
                    ),
                    const SizedBox(height: 6),
                    Text('circle', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmartImage(
                      image: SampleData.samplePngAsset,
                      width: 96,
                      height: 96,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(height: 6),
                    Text('rounded', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          description:
              'Clip to a circle for avatars, or round the corners with a '
              'borderRadius — no ClipRRect/ClipOval boilerplate.',
          code: 'shape: BoxShape.circle\nborderRadius: BorderRadius.circular(20)',
        ),

        DemoCard(
          title: 'Placeholders (loaders)',
          source: null,
          preview: PreviewFrame(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _loaderSample(context, 'shimmer', const ShimmerLoader()),
                _loaderSample(context, 'skeleton', const SkeletonLoader()),
                _loaderSample(
                  context,
                  'circular',
                  const SmartLoader(type: LoaderType.circular, progress: 0.6),
                ),
              ],
            ),
          ),
          description:
              'While an image loads you get a placeholder for free. Pick a '
              'built-in style or supply your own loadingBuilder. Circular turns '
              'determinate when download progress is known.',
          code: 'loaderType: LoaderType.shimmer',
          useWhen: 'shimmer/skeleton for lists; circular when progress matters.',
        ),

        DemoCard(
          title: 'BlurHash placeholder',
          source: DemoSource.network,
          preview: PreviewFrame(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 120,
                        height: 120,
                        child: BlurHashView(hash: SampleData.demoBlurHash),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('blur shown first',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SmartImage(
                      image: 'https://picsum.photos/id/1062/300/300',
                      blurHash: SampleData.demoBlurHash,
                      width: 120,
                      height: 120,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    const SizedBox(height: 6),
                    Text('then the photo',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          description:
              'A BlurHash renders an instant, recognisable blur from a tiny '
              'string while the full image downloads — decoded natively, no '
              'extra package.',
          code: "blurHash: 'L6PZfSi_.AyE_3t7t7R**0o#DgR4'",
          useWhen: 'Use for hero/header images where a grey box feels jarring.',
        ),

        DemoCard(
          title: 'Effects (off the UI thread)',
          source: DemoSource.asset,
          preview: PreviewFrame(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _effect(context, 'original',
                    const SmartImage(image: SampleData.samplePngAsset)),
                _effect(context, 'grayscale',
                    const SmartImage(image: SampleData.samplePngAsset, grayscale: true)),
                _effect(context, 'blur',
                    const SmartImage(image: SampleData.samplePngAsset, blur: 3)),
              ],
            ),
          ),
          description:
              'grayscale, blur, brightness, contrast and saturation are applied '
              'in a background isolate, so scrolling never janks.',
          code: 'grayscale: true\nblur: 3\nsaturation: 1.4',
          avoidWhen: 'Prefer pre-processing static assets at build time when you can.',
        ),

        const DemoCard(
          title: 'Tint colour',
          source: DemoSource.svg,
          preview: PreviewFrame(
            height: 130,
            child: SmartImage(
              image: SampleData.logoSvgAsset,
              width: 100,
              height: 100,
              color: Color(0xFF1E88E5),
            ),
          ),
          description:
              'A color tints both raster and SVG images — handy for theming '
              'monochrome icons.',
          code: 'color: Colors.blue',
        ),

        const DemoCard(
          title: 'Error → fallback icon',
          source: DemoSource.network,
          preview: PreviewFrame(
            child: SmartImage(
              image: 'https://invalid.example.invalid/missing.png',
              width: 110,
              height: 110,
              retryCount: 1,
              fallbackIcon: Icons.image_not_supported_outlined,
            ),
          ),
          description:
              'When loading fails after retries, SmartImageX walks a fallback '
              'chain: fallback image → fallback icon → error widget. Here a bad '
              'URL lands on an icon.',
          code: 'fallbackIcon: Icons.image_not_supported_outlined',
        ),

        const DemoCard(
          title: 'Error → fallback to an asset',
          source: DemoSource.network,
          preview: PreviewFrame(
            child: SmartImage(
              image: 'https://invalid.example.invalid/avatar.png',
              width: 110,
              height: 110,
              shape: BoxShape.circle,
              retryCount: 0,
              fallbackImage: SampleData.avatarSvgAsset,
            ),
          ),
          description:
              'A failed avatar gracefully falls back to a bundled placeholder '
              'asset — the fallback itself flows through the full pipeline.',
          code: "fallbackImage: 'assets/avatar_placeholder.svg'",
          useWhen: 'Use for user avatars and any image that might 404.',
        ),
      ],
    );
  }

  Widget _loaderSample(BuildContext context, String label, Widget loader) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 90, height: 90, child: loader),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _effect(BuildContext context, String label, Widget image) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 90, height: 90, child: image),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
