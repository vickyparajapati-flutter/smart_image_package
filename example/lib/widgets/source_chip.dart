import 'package:flutter/material.dart';

/// The kind of image source a demo illustrates. Drives the coloured badge so a
/// reader can tell at a glance whether they're looking at a network image, raw
/// bytes, an SVG, an asset, and so on.
enum DemoSource {
  network('Network', Icons.cloud_outlined, Color(0xFF1E88E5)),
  asset('Asset', Icons.folder_outlined, Color(0xFF2E7D32)),
  svg('SVG', Icons.polyline_outlined, Color(0xFFEF6C00)),
  memory('Memory', Icons.memory_outlined, Color(0xFF6A1B9A)),
  base64('Base64', Icons.data_object_outlined, Color(0xFF00897B)),
  file('File', Icons.insert_drive_file_outlined, Color(0xFF5D4037));

  const DemoSource(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// A small pill that labels the source type of a demo image.
class SourceChip extends StatelessWidget {
  const SourceChip(this.source, {super.key});

  final DemoSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: source.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: source.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 14, color: source.color),
          const SizedBox(width: 5),
          Text(
            source.label,
            style: TextStyle(
              color: source.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
