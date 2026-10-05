import '../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Content-sized clinical status/severity/risk pill. Role accents must not
/// override its meaning (see [ClinicalColors]).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.palette});

  final String label;
  final ChipPalette palette;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.foreground.withValues(alpha: 0.18)),
        ),
        child: Text(
          context.tr(label),
          style: TextStyle(
            color: palette.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
