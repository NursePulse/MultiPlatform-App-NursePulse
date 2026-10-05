import '../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'brand_mark.dart';
import 'language_selector.dart';

/// Both auth forms stay scrollable with the keyboard and enlarged text.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(context).extension<RoleAppearance>()?.header ??
                    AppTheme.evergreen,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(0)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: LanguageSelector(light: true),
                      ),
                      if (onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: context.tr('Volver a iniciar sesión'),
                            onPressed: onBack,
                            icon: Icon(Icons.arrow_back, color: Colors.white),
                          ),
                        ),
                      BrandWordmark(light: true, large: true),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr(title),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 8),
                      Text(
                        context.tr(subtitle),
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
