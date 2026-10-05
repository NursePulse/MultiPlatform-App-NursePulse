import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale_notifier.dart';
import '../../core/localization/app_strings.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key, this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return PopupMenuButton<String>(
      key: const ValueKey('language-selector'),
      tooltip: context.tr('Cambiar idioma'),
      initialValue: locale.languageCode,
      onSelected: (code) async {
        final saved = await ref.read(localeProvider.notifier).select(code);
        if (!saved && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'Idioma cambiado. No se pudo guardar la preferencia.',
                ),
              ),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          key: const ValueKey('language-es'),
          value: 'es',
          checked: locale.languageCode == 'es',
          child: const Text('Español · ES'),
        ),
        CheckedPopupMenuItem(
          key: const ValueKey('language-en'),
          value: 'en',
          checked: locale.languageCode == 'en',
          child: const Text('English · EN'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, size: 20, color: light ? Colors.white : null),
            const SizedBox(width: 5),
            Text(
              locale.languageCode.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: light ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
