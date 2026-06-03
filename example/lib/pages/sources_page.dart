import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smart_image_x/smart_image_x.dart';

import '../sample_data.dart';
import '../widgets/demo_card.dart';
import '../widgets/source_chip.dart';

/// Demonstrates every image *source* SmartImageX auto-detects, each with a
/// plain-language explanation of when to reach for it.
class SourcesPage extends StatefulWidget {
  const SourcesPage({super.key});

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  Uint8List? _bytes;
  String? _base64;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await SampleData.bytes();
    final base64 = await SampleData.base64DataUri();
    final filePath = await SampleData.tempFilePath();
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _base64 = base64;
      _filePath = filePath;
    });
  }

  Widget _preview(Object image, {BoxFit fit = BoxFit.cover}) {
    return SmartImage(
      image: image,
      width: 220,
      height: 150,
      fit: fit,
      borderRadius: BorderRadius.circular(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionIntro(
          title: 'Image sources',
          subtitle:
              'One widget, any source. SmartImageX inspects the value you pass '
              'and picks the right loader — no type flags needed.',
        ),
        const SizedBox(height: 8),

        DemoCard(
          title: 'Network URL',
          source: DemoSource.network,
          preview: _preview(SampleData.networkPhotos[0]),
          description:
              'A remote http/https image. Downloaded once, then cached to '
              'memory + disk; subsequent loads are instant and work offline. '
              'Retries and a placeholder are automatic.',
          code: "SmartImage(image: 'https://…/photo.jpg')",
          useWhen: 'Use for API / CDN images and anything that changes at runtime.',
          avoidWhen: 'Avoid for app icons you ship in the bundle — use an asset.',
        ),

        DemoCard(
          title: 'Bundled asset (raster)',
          source: DemoSource.asset,
          preview: _preview(SampleData.samplePngAsset),
          description:
              'A PNG/JPG/WebP shipped inside the app. Detected from the '
              '"assets/…" path. No network, no cache needed — Flutter decodes it '
              'lazily.',
          code: "SmartImage(image: 'assets/sample.png')",
          useWhen: 'Use for images you ship with the app (illustrations, logos).',
        ),

        DemoCard(
          title: 'Bundled asset (SVG)',
          source: DemoSource.svg,
          preview: PreviewFrame(
            height: 150,
            child: _preview(SampleData.logoSvgAsset, fit: BoxFit.contain),
          ),
          description:
              'An .svg asset, auto-detected by extension and rendered as crisp '
              'vector at any size. No separate SVG widget required.',
          code: "SmartImage(image: 'assets/logo.svg')",
          useWhen: 'Use for scalable icons/illustrations that must stay sharp.',
        ),

        DemoCard(
          title: 'Inline SVG markup',
          source: DemoSource.svg,
          preview: PreviewFrame(
            height: 150,
            child: _preview(SampleData.inlineSvg, fit: BoxFit.contain),
          ),
          description:
              'Raw "<svg>…</svg>" text — e.g. returned from an API or generated '
              'at runtime. Recognised by its markup, not a file path.',
          code: "SmartImage(image: '<svg>…</svg>')",
          useWhen: 'Use for SVG strings from a backend or built on the fly.',
        ),

        if (_bytes != null)
          DemoCard(
            title: 'In-memory bytes',
            source: DemoSource.memory,
            preview: _preview(_bytes!),
            description:
                'A Uint8List you already hold in memory — decoded uploads, '
                'generated images, or bytes from a database. Shown directly, '
                'no I/O.',
            code: 'SmartImage(image: myUint8List)',
            useWhen: 'Use for bytes you already have (camera capture, DB blobs).',
          ),

        if (_base64 != null)
          DemoCard(
            title: 'Base64 / data URI',
            source: DemoSource.base64,
            preview: _preview(_base64!),
            description:
                'A base64 string or full "data:image/…;base64,…" URI is decoded '
                'automatically — common in JSON payloads and inline HTML.',
            code: "SmartImage(image: 'data:image/png;base64,…')",
            useWhen: 'Use for small images embedded in JSON / HTML responses.',
            avoidWhen: 'Avoid for large images — base64 is ~33% bigger than binary.',
          ),

        if (_filePath != null)
          DemoCard(
            title: 'Local file',
            source: DemoSource.file,
            preview: _preview(_filePath!),
            description:
                'An absolute file path on the device — a downloaded file, a '
                'picked photo, or a cached document. Detected from the path '
                'shape.',
            code: "SmartImage(image: '/path/to/photo.png')",
            useWhen: 'Use for files on disk (image_picker results, downloads).',
          )
        else
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
