import 'package:flutter/material.dart';

/// Independent panels fit side by side only with enough readable space.
/// No fixed heights: long content and enlarged text retain normal scrolling.
class ResponsivePanels extends StatelessWidget {
  const ResponsivePanels({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = constraints.maxWidth >= 840 * scale ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 20) / columns;
      return Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
