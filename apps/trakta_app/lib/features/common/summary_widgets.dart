import 'package:flutter/material.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import 'format.dart';

// Building blocks of the summary screens (DESIGN.md "Stat tile", "Overview").

/// A card on a summary screen (overview, commuting), optionally with a
/// tappable header that opens the full list.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, this.title, this.icon, this.onOpen, required this.children});

  final String? title;
  final IconData? icon;
  final VoidCallback? onOpen;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            ListTile(
              leading: Icon(icon),
              title: Text(title, style: Theme.of(context).textTheme.titleMedium),
              trailing: onOpen == null ? null : const Icon(Icons.chevron_right),
              onTap: onOpen,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(Space.md, title == null ? Space.md : 0, Space.md, Space.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: text.titleLarge),
        ],
      ),
    );
  }
}

class AmountRow extends StatelessWidget {
  const AmountRow({super.key, required this.label, required this.amount, this.icon, this.total = false, this.muted = false});

  final String label;
  final Ore amount;
  final IconData? icon;

  /// The deduction line: bold and in the positive colour (DESIGN.md).
  final bool total;

  /// Shown for context only, not part of the deduction.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var style = total ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
    if (muted) style = style?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final amountStyle = total ? style?.copyWith(color: TraktaColors.of(context).positive) : style;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: Space.sm),
          ],
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: Space.sm),
          Text(context.money(amount), style: amountStyle),
        ],
      ),
    );
  }
}
