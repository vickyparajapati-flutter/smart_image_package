import 'package:flutter/material.dart';

import 'source_chip.dart';

/// A consistent, screenshot-friendly card used throughout the example.
///
/// Each card pairs a live [SmartImage] preview with everything a developer
/// needs to understand it: a title, a source-type badge, a one-line summary, an
/// optional code snippet, and concise "use when / avoid when" guidance.
class DemoCard extends StatelessWidget {
  const DemoCard({
    required this.title,
    required this.source,
    required this.description,
    required this.preview,
    this.code,
    this.useWhen,
    this.avoidWhen,
    super.key,
  });

  final String title;
  final DemoSource? source;
  final String description;
  final Widget preview;
  final String? code;
  final String? useWhen;
  final String? avoidWhen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (source != null) SourceChip(source!),
              ],
            ),
            const SizedBox(height: 14),
            Center(child: preview),
            const SizedBox(height: 14),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (code != null) ...[
              const SizedBox(height: 12),
              _CodeBlock(code!),
            ],
            if (useWhen != null || avoidWhen != null) ...[
              const SizedBox(height: 12),
              if (useWhen != null)
                _Note(
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF2E7D32),
                  text: useWhen!,
                ),
              if (avoidWhen != null) ...[
                const SizedBox(height: 6),
                _Note(
                  icon: Icons.warning_amber_outlined,
                  color: const Color(0xFFEF6C00),
                  text: avoidWhen!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A framed pedestal so previews (especially transparent/SVG ones) read clearly
/// against both light and dark backgrounds.
class PreviewFrame extends StatelessWidget {
  const PreviewFrame({required this.child, this.height = 160, super.key});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.45,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// A lightweight section intro shown at the top of each page.
class SectionIntro extends StatelessWidget {
  const SectionIntro({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
