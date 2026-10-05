import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/localization/app_strings.dart';
import 'package:nurse_pulse_app/core/localization/locale_notifier.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/router/app_router.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';
import 'package:nurse_pulse_app/main.dart';
import 'package:nurse_pulse_app/shared/widgets/status_chip.dart';
import 'package:nurse_pulse_app/shared/widgets/page_title.dart';

import '../dashboard/fixtures.dart' as fixtures;
import 'responsive_ui_test.dart' show viewport;
import 'session_isolation_test.dart'
    show SessionStore, clinicalReply, simulatedDio;

class MemoryLocaleStore extends LocaleStore {
  String? saved;
  bool failRead = false, failWrite = false;
  Completer<String?>? pendingRead;
  final writes = <String>[];
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Preference unavailable');
    return pendingRead?.future ?? saved;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('Preference unavailable');
    writes.add(value);
    saved = value;
  }
}

class SignedOutStore extends SessionStore {
  @override
  Future<String?> readToken() async => null;
  @override
  Future<Map<String, dynamic>?> readUser() async => null;
}

void main() {
  test(
    'ES/EN persists across notifier recreation; invalid value defaults to ES',
    () async {
      final store = MemoryLocaleStore()..saved = 'unsupported';
      final first = LocaleNotifier(store);
      await Future<void>.delayed(Duration.zero);
      expect(first.state.languageCode, 'es');
      expect(await first.select('en'), isTrue);
      first.dispose();
      final restored = LocaleNotifier(store);
      addTearDown(restored.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(restored.state.languageCode, 'en');
      expect(await restored.select('unknown'), isFalse);
      expect(restored.state.languageCode, 'en');
    },
  );
  test(
    'late preference restoration does not override an explicit choice',
    () async {
      final store = MemoryLocaleStore()..pendingRead = Completer<String?>();
      final notifier = LocaleNotifier(store);
      addTearDown(notifier.dispose);
      await notifier.select('en');
      store.pendingRead!.complete('es');
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.languageCode, 'en');
      expect(store.saved, 'en');
    },
  );
  test('rapid language choices persist the last selection', () async {
    final store = MemoryLocaleStore();
    final notifier = LocaleNotifier(store);
    addTearDown(notifier.dispose);
    await Future.wait([
      notifier.select('en'),
      notifier.select('es'),
      notifier.select('en'),
    ]);
    expect(store.writes, ['en', 'es', 'en']);
    expect(store.saved, 'en');
  });
  test(
    'preference failures do not block the app; saving failure is reported',
    () async {
      final store = MemoryLocaleStore()
        ..failRead = true
        ..failWrite = true;
      final notifier = LocaleNotifier(store);
      addTearDown(notifier.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.languageCode, 'es');
      expect(await notifier.select('en'), isFalse);
      expect(notifier.state.languageCode, 'en');
    },
  );
  test('template translation preserves interpolated names and IDs', () {
    expect(
      translateAppText('¿Dar de alta a Nombre de prueba?', 'en'),
      'Discharge Nombre de prueba?',
    );
    expect(translateAppText('Paciente #123', 'en'), 'Patient #123');
    expect(
      translateAppText('Resolución: Nota clínica de prueba', 'en'),
      'Resolution: Nota clínica de prueba',
    );
    expect(
      translateAppText('Detalle desconocido del servidor', 'en'),
      'Detalle desconocido del servidor',
    );
    expect(translateAppText('Pacientes', 'es'), 'Pacientes');
  });
  testWidgets('page heading stays compact under bounded height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PageTitle('Usuarios', subtitle: '22 cuentas'),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PageTitle)).height, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  for (final actor in [fixtures.nurse, fixtures.doctor, fixtures.admin]) {
    for (final language in ['es', 'en']) {
      for (final configuration in [
        (const Size(390, 844), 1.0),
        (const Size(320, 640), 2.0),
        (const Size(1024, 768), 1.0),
      ]) {
        testWidgets(
          'Actual app ${actor.primaryRole} $language ${configuration.$1} scale ${configuration.$2}',
          (tester) async {
            viewport(tester, configuration.$1);
            final calls = <String>[];
            final store = MemoryLocaleStore()..saved = language;
            final container = ProviderContainer(
              overrides: [
                localeStoreProvider.overrideWithValue(store),
                secureStoreProvider.overrideWithValue(
                  SessionStore(actor: actor),
                ),
                dioProvider.overrideWithValue(
                  simulatedDio(clinicalReply, calls),
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
                    size: configuration.$1,
                    textScaler: TextScaler.linear(configuration.$2),
                  ),
                  child: const NursePulseApp(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final scheme = Theme.of(
              tester.element(find.byType(PageTitle).first),
            ).colorScheme;
            expect(scheme.primary, switch (actor.primaryRole) {
              kRoleDoctor => const Color(0xFF1D4ED8),
              kRoleAdmin => const Color(0xFF85621D),
              _ => const Color(0xFF0F766E),
            });
            expect(container.read(localeProvider).languageCode, language);
            for (final path in [
              '/dashboard',
              '/patients',
              '/patients/1/monitoring',
              '/vital-signs',
              '/clinical-events',
              '/sbar',
              '/alerts',
              '/reports',
              '/audit',
              '/users',
              '/subscriptions',
            ]) {
              router.go(path);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: path);
            }
            expect(calls.every((call) => call.startsWith('GET ')), isTrue);
          },
        );
      }
    }
  }

  testWidgets(
    'language selector updates navigation without re-fetching clinical data',
    (tester) async {
      final calls = <String>[];
      final store = MemoryLocaleStore();
      final container = ProviderContainer(
        overrides: [
          localeStoreProvider.overrideWithValue(store),
          secureStoreProvider.overrideWithValue(SessionStore()),
          dioProvider.overrideWithValue(simulatedDio(clinicalReply, calls)),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);
      viewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NursePulseApp(),
        ),
      );
      await tester.pumpAndSettle();
      final before = List<String>.of(calls);
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Patients'), findsOneWidget);
      expect(store.saved, 'en');
      expect(calls, before);
      await tester.scrollUntilVisible(
        find.text('Patient monitoring'),
        250,
        scrollable: find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seguimiento de pacientes'), findsNothing);
    },
  );

  testWidgets(
    'login keeps typed data when switching ES/EN; invalid fields do not reach API',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final calls = <String>[];
      final store = MemoryLocaleStore();
      final container = ProviderContainer(
        overrides: [
          localeStoreProvider.overrideWithValue(store),
          secureStoreProvider.overrideWithValue(SignedOutStore()),
          dioProvider.overrideWithValue(simulatedDio(clinicalReply, calls)),
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
      await tester.enterText(find.byType(TextFormField).first, 'staff.demo');
      await tester.tap(find.byKey(const ValueKey('language-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'staff.demo',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sign-in password must have 8 to 72 characters.'),
        findsOneWidget,
      );
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'clinical notes stay verbatim in English monitoring and the header offers back navigation',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          localeStoreProvider.overrideWithValue(
            MemoryLocaleStore()..saved = 'en',
          ),
          secureStoreProvider.overrideWithValue(SessionStore()),
          dioProvider.overrideWithValue(
            simulatedDio((request) {
              final reply = clinicalReply(request);
              if (request.path == '/patients/1') {
                return {
                  ...reply as Map<String, dynamic>,
                  'firstName': 'Nombre',
                  'lastName': 'Demo',
                  'diagnosis': 'Paciente',
                };
              }
              return reply;
            }, calls),
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
      router.go('/patients/1/monitoring');
      await tester.pumpAndSettle();
      expect(find.text('Monitoring'), findsOneWidget);
      expect(find.text('Nombre Demo'), findsOneWidget);
      expect(
        find.text('Paciente'),
        findsOneWidget,
      ); // Diagnosis matches an app label but is clinical data.
      expect(find.text('Diagnosis:'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(StatusChip), findsWidgets);
      await tester.tap(find.byTooltip('Back to patients'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/patients');
      expect(calls.every((call) => call.startsWith('GET ')), isTrue);
    },
  );

  testWidgets(
    'English reports use localized calendars and spaced fields; invalid title never generates',
    (tester) async {
      viewport(tester, const Size(390, 844));
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          localeStoreProvider.overrideWithValue(
            MemoryLocaleStore()..saved = 'en',
          ),
          secureStoreProvider.overrideWithValue(
            SessionStore(actor: fixtures.admin),
          ),
          dioProvider.overrideWithValue(simulatedDio(clinicalReply, calls)),
          reportLocalStoreProvider.overrideWithValue(
            ReportLocalStore(
              read: () async => null,
              write: (_) async {
                fail('An invalid report must not be saved');
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
      await tester.tap(find.byKey(const ValueKey('report-new')));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('report-title'));
      final type = find.byKey(const ValueKey('report-type'));
      expect(
        tester.getTopLeft(type).dy - tester.getBottomLeft(title).dy,
        greaterThanOrEqualTo(12),
      );
      final dates = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('report-date-'),
      );
      await tester.tap(dates.first);
      await tester.pumpAndSettle();
      expect(
        Localizations.localeOf(tester.element(find.byType(DatePickerDialog)))
            .languageCode,
        'en',
      );
      expect(find.text('Cancel'), findsWidgets);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      final before = List<String>.of(calls);
      await tester.tap(find.byKey(const ValueKey('report-generate')));
      await tester.pumpAndSettle();
      expect(find.text('Title is required.'), findsOneWidget);
      expect(calls, before);
      expect(tester.takeException(), isNull);
    },
  );
}
