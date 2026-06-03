import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:smart_image_x/smart_image_x.dart';

import '../sample_data.dart';
import '../widgets/demo_card.dart';

/// Interactive demo of the standalone [SmartImageTools] utilities — compress,
/// resize, transform — plus image metadata, all running off the UI thread.
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  Uint8List? _original;
  Uint8List? _result;
  ImageMetadata? _meta;
  String _resultLabel = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bytes = await SampleData.bytes();
    final meta = await SmartImage.getMetadata(bytes);
    if (!mounted) return;
    setState(() {
      _original = bytes;
      _meta = meta;
    });
  }

  Future<void> _run(String label, Future<Uint8List> Function(Uint8List) op) async {
    if (_original == null || _busy) return;
    setState(() => _busy = true);
    final out = await op(_original!);
    if (!mounted) return;
    setState(() {
      _result = out;
      _resultLabel = label;
      _busy = false;
    });
  }

  String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final original = _original;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionIntro(
          title: 'Image tools',
          subtitle:
              'Compress, resize, crop and transform raw bytes outside the '
              'widget — every operation runs in a background isolate.',
        ),
        const SizedBox(height: 8),

        if (_meta != null)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Metadata  •  SmartImage.getMetadata()',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _metaRow('Dimensions', '${_meta!.width} × ${_meta!.height}'),
                  _metaRow('Format', _meta!.format.name.toUpperCase()),
                  _metaRow('Size', _kb(_meta!.sizeInBytes)),
                  _metaRow('Aspect ratio', _meta!.aspectRatio.toStringAsFixed(2)),
                  _metaRow('Has alpha', _meta!.hasAlpha ? 'yes' : 'no'),
                ],
              ),
            ),
          ),

        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Run an operation', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _toolButton('Compress→JPEG q40', () => _run(
                          'Compressed to JPEG (quality 40)',
                          (b) => SmartImageTools.compressImage(
                            b,
                            format: CompressionFormat.jpg,
                            quality: 40,
                          ),
                        )),
                    _toolButton('Resize → 150w', () => _run(
                          'Resized to 150px wide',
                          (b) => SmartImageTools.resizeImage(b, width: 150),
                        )),
                    _toolButton('Grayscale', () => _run(
                          'Greyscale',
                          (b) => SmartImageTools.transform(
                            b,
                            const TransformSpec(grayscale: true),
                          ),
                        )),
                    _toolButton('Rotate 90°', () => _run(
                          'Rotated 90°',
                          (b) => SmartImageTools.rotateImage(b, 90),
                        )),
                    _toolButton('Flip ↔', () => _run(
                          'Flipped horizontally',
                          (b) => SmartImageTools.flipImage(b),
                        )),
                    _toolButton('Crop centre', () => _run(
                          'Cropped to centre square',
                          (b) => SmartImageTools.cropImage(
                            b,
                            x: 150,
                            y: 75,
                            width: 300,
                            height: 300,
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                if (original != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _resultColumn(
                          context,
                          'Original',
                          original,
                          _kb(original.length),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _busy
                            ? const SizedBox(
                                height: 140,
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : _result == null
                                ? _placeholderColumn(context)
                                : _resultColumn(
                                    context,
                                    _resultLabel,
                                    _result!,
                                    _kb(_result!.length),
                                  ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: Theme.of(context).textTheme.bodyMedium),
          Text(v,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _toolButton(String label, VoidCallback onTap) {
    return FilledButton.tonal(
      onPressed: _busy ? null : onTap,
      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      child: Text(label),
    );
  }

  Widget _resultColumn(
    BuildContext context,
    String label,
    Uint8List bytes,
    String size,
  ) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SmartImage(image: bytes, height: 140, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium),
        Text(size, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _placeholderColumn(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: const Center(child: Text('Result')),
        ),
        const SizedBox(height: 6),
        Text('Pick an operation',
            style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
