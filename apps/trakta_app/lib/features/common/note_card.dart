import 'package:flutter/material.dart';

import '../../app/tokens.dart';

/// A neutral note (DESIGN.md "Banner", neutral): a title, a bulleted list
/// and an optional closing line, e.g. the requirements for a deduction.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.title, required this.bullets, this.footer, this.margin = EdgeInsets.zero});

  final String title;
  final List<String> bullets;
  final String? footer;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final footer = this.footer;
    return Card(
      margin: margin,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleSmall),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('•  '), Expanded(child: Text(b))],
                ),
              ),
            if (footer != null) ...[
              const SizedBox(height: Space.sm),
              Text(footer, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
