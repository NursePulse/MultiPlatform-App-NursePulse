import '../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';

/// Consistent cards with room for long names, notes and enlarged text.
class ClinicalCard extends StatelessWidget {
  const ClinicalCard({
    super.key,
    required this.children,
    this.accent,
    this.onTap,
    this.cardKey,
  });
  final List<Widget> children;
  final Color? accent;
  final VoidCallback? onTap;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) => Card(
    key: cardKey,
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: InkWell(
      onTap: onTap,
      child: Container(
        decoration: accent == null
            ? null
            : BoxDecoration(
                border: Border(left: BorderSide(color: accent!, width: 5)),
              ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    ),
  );
}

class InfoField extends StatelessWidget {
  const InfoField(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr(label), style: Theme.of(context).textTheme.bodySmall),
        SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

/// Two columns when labels/values fit; one column for enlarged text.
class InfoGrid extends StatelessWidget {
  const InfoGrid({super.key, required this.fields});
  final List<InfoField> fields;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 280 &&
              MediaQuery.textScalerOf(context).scale(15) < 22
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final field in fields) SizedBox(width: width, child: field),
        ],
      );
    },
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.count, {super.key});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.tr(title),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(width: 8),
        CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            context.tr('$count'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}
