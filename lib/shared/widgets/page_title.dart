import 'package:flutter/material.dart';

/// Replaces a per-screen `Scaffold(appBar: AppBar(title: ...))` with an
/// inline heading. Every feature screen is rendered inside AppShell, which
/// already renders a persistent header (menu/app name/account chip); a
/// second, per-screen AppBar on top of that just adds an invisible block of
/// space (the theme's AppBarTheme has elevation 0 and the same background as
/// the scaffold, so it renders as blank space instead of a visible bar).
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}
