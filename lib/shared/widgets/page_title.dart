import '../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';

/// Compact inline heading below the shared shell header. Its content shrinks
/// vertically so a title does not consume the space intended for the list.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(title),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6),
              Text(
                context.tr(subtitle!),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
