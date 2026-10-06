import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/localization/app_strings.dart';
import 'package:nurse_pulse_app/core/localization/locale_notifier.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/router/app_router.dart';
import 'package:nurse_pulse_app/core/theme/app_theme.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';
import 'package:nurse_pulse_app/main.dart';
import 'package:nurse_pulse_app/shared/widgets/audit_entry_card.dart';
import 'package:nurse_pulse_app/shared/widgets/form_sheet.dart';
import 'package:nurse_pulse_app/shared/widgets/page_action.dart';
import 'package:nurse_pulse_app/shared/widgets/status_chip.dart';

import '../dashboard/fixtures.dart' as staff;
import '../notification/fixtures.dart' as alerts;
import 'responsive_ui_test.dart' show viewport;
import 'session_isolation_test.dart'
    show SessionStore, clinicalReply, simulatedDio;
import 'ui_role_locale_test.dart' show MemoryLocaleStore;

void main() {
  testWidgets('severity pill keeps content width in a stretched column', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                StatusChip(
                  label: 'Crítica',
                  palette: ClinicalColors.riskCritical,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final pill = find.descendant(
      of: find.byType(StatusChip),
      matching: find.byType(Container),
    );
    expect(tester.getSize(pill).width, lessThan(160));
    expect(find.text('Crítica'), findsOneWidget);
  });

  for (final actor in [staff.nurse, staff.doctor, staff.admin]) {
    for (final language in ['es', 'en']) {
      for (final config in [
        (const Size(320, 640), 1.0),
        (const Size(390, 844), 2.0),
      ]) {
        testWidgets(
          'alert severity, reachable actions and read-only browsing ${actor.primaryRole} $language $config',
          (tester) async {
            viewport(tester, config.$1);
            final calls = <String>[];
            const severities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
            final container = ProviderContainer(
              overrides: [
                localeStoreProvider.overrideWithValue(
                  MemoryLocaleStore()..saved = language,
                ),
                secureStoreProvider.overrideWithValue(
                  SessionStore(actor: actor),
                ),
                dioProvider.overrideWithValue(
                  simulatedDio(
                    (request) => request.path == '/alerts'
                        ? [
                            for (var i = 0; i < severities.length; i++)
                              alerts.alertJson(
                                id: '${i + 9}',
                                severity: severities[i],
                              ),
                          ]
                        : clinicalReply(request),
                    calls,
                  ),
                ),
                reportLocalStoreProvider.overrideWithValue(
                  ReportLocalStore(read: () async => null, write: (_) async {}),
                ),
              ],
            );
            addTearDown(container.dispose);
            final router = container.read(appRouterProvider);
            addTearDown(router.dispose);
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: config.$1,
                    textScaler: TextScaler.linear(config.$2),
                  ),
                  child: const NursePulseApp(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            // MaterialApp derives its own MediaQuery; apply accessibility to the view.
            tester.platformDispatcher.textScaleFactorTestValue = config.$2;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            router.go('/alerts');
            await tester.pumpAndSettle();
            expect(find.byType(FloatingActionButton), findsNothing);
            final action = find.descendant(
              of: find.byType(PageAction),
              matching: find.byType(FilledButton),
            );
            expect(action, findsOneWidget);
            final scroll = find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first;
            for (var i = 0; i < severities.length; i++) {
              final card = find.byKey(ValueKey('alert-card-${i + 9}'));
              await tester.scrollUntilVisible(card, 250, scrollable: scroll);
              await tester.pumpAndSettle();
              final stripe = find.descendant(
                of: card,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      w.decoration is BoxDecoration &&
                      (w.decoration as BoxDecoration).border != null,
                ),
              );
              final border =
                  (tester.widget<Container>(stripe.first).decoration
                              as BoxDecoration)
                          .border!
                      as Border;
              expect(
                border.left.color,
                ClinicalColors.severityAccent(severities[i]),
              );
              expect(border.left.width, 5);
              final attend = find.descendant(
                of: card,
                matching: find.widgetWithText(
                  FilledButton,
                  language == 'es' ? 'Atender' : 'Attend',
                ),
              );
              await tester.ensureVisible(attend);
              await tester.pumpAndSettle();
              expect(attend.hitTestable(), findsOneWidget);
              expect(
                tester.getBottomRight(attend).dy,
                lessThanOrEqualTo(
                  tester.getTopLeft(find.byType(NavigationBar)).dy,
                ),
              );
              expect(tester.takeException(), isNull);
            }
            expect(calls.every((call) => call.startsWith('GET ')), isTrue);
          },
        );
      }
    }
  }

  testWidgets('abbreviated reference opens the exact selectable identifier', (
    tester,
  ) async {
    const id = '11111111-2222-3333-4444-555555555555';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: EntityReference('Paciente', id)),
      ),
    );
    expect(find.text('Paciente #11111111…555555'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SelectableText, 'Paciente #$id'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    testWidgets('report sheet with keyboard keeps actions reachable $size', (
      tester,
    ) async {
      viewport(tester, size);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          localeStoreProvider.overrideWithValue(MemoryLocaleStore()),
          secureStoreProvider.overrideWithValue(
            SessionStore(actor: staff.doctor),
          ),
          dioProvider.overrideWithValue(simulatedDio(clinicalReply, calls)),
          reportLocalStoreProvider.overrideWithValue(
            ReportLocalStore(
              read: () async => null,
              write: (_) async {
                fail('Invalid title cannot save');
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NursePulseApp(),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/reports');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('report-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-new')));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsOneWidget);
      final submit = find.byKey(const ValueKey('report-generate'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('report-title'));
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      expect(find.text('El título es obligatorio.'), findsOneWidget);
      expect(calls.every((call) => call.startsWith('GET ')), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  test('new metadata and measured units retain ES/EN support', () {
    expect(translateAppText('De: nurse.demo', 'en'), 'From: nurse.demo');
    expect(
      translateAppText('Incluye todo el día de la fecha final.', 'en'),
      'Includes the entire final day.',
    );
  });
}
