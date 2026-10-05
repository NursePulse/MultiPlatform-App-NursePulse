import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';

/// Keep actions separate when there is room; use one continuous scroll with
/// the keyboard or enlarged text so neither header nor footer can overflow.
class FormSheet extends StatelessWidget {
  const FormSheet({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    required this.busy,
  });
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    final heading = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(title),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: context.tr('Cerrar'),
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
    final footer = Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.end,
        children: actions,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: math.max(0, math.min(available, media.size.height * 0.9)),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight < 440 ||
                  media.textScaler.scale(15) >= 22) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: content,
                      ),
                      const Divider(height: 1),
                      footer,
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  heading,
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: content,
                    ),
                  ),
                  const Divider(height: 1),
                  footer,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
