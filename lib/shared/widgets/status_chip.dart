import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Status/severity/risk pill, rendered with the exact background+foreground
/// pair used for the same state in the Angular web app (see [ClinicalColors]).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.palette});

  final String label;
  final ChipPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
