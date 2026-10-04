import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/router/app_router.dart';
import 'package:nurse_pulse_app/core/theme/app_theme.dart';
import 'package:nurse_pulse_app/features/iam/application/auth_notifier.dart';
import 'package:nurse_pulse_app/features/iam/presentation/sign_in_view.dart';
import 'package:nurse_pulse_app/features/iam/presentation/sign_up_view.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';

import '../dashboard/fixtures.dart' as fixtures;
import 'session_isolation_test.dart'
    show SessionStore, clinicalReply, simulatedDio;

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final actor in [fixtures.nurse, fixtures.doctor, fixtures.admin]) {
    for (final config in [
      (const Size(320, 640), 1.0),
      (const Size(390, 844), 2.0),
      (const Size(844, 390), 1.0),
      (const Size(844, 390), 2.0),
      (const Size(1024, 768), 1.0),
      (const Size(1280, 720), 2.0),
    ]) {
      testWidgets(
        'UI completa ${actor.primaryRole} ${config.$1} texto ${config.$2}',
        (tester) async {
          viewport(tester, config.$1);
          final calls = <String>[];
          final container = ProviderContainer(
            overrides: [
              secureStoreProvider.overrideWithValue(SessionStore(actor: actor)),
              dioProvider.overrideWithValue(simulatedDio(clinicalReply, calls)),
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
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(config.$2)),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (config.$1.width < 900) {
            await tester.tap(find.byType(NavigationDestination).at(1));
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, '/patients');
            await tester.tap(find.byType(NavigationDestination).at(2));
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, '/alerts');
            await tester.tap(find.byType(NavigationDestination).at(3));
            await tester.pumpAndSettle();
            expect(find.byType(Drawer), findsOneWidget);
            Navigator.of(tester.element(find.byType(Drawer))).pop();
            await tester.pumpAndSettle();
          } else {
            expect(find.byType(NavigationBar), findsNothing);
            final nav = find.byType(ListView).first;
            await tester.scrollUntilVisible(
              find.text('Suscripciones'),
              150,
              scrollable: find.descendant(
                of: nav,
                matching: find.byType(Scrollable),
              ),
            );
            await tester.ensureVisible(find.text('Suscripciones'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Suscripciones'));
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.path,
              '/subscriptions',
            );
          }
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
          if (actor == fixtures.nurse) {
            expect(calls.any((call) => call.contains('/audit-logs')), isFalse);
          }
        },
      );
    }
  }

  for (final registration in [false, true]) {
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(1024, 768),
    ]) {
      testWidgets(
        'Autenticación ${registration ? 'registro' : 'login'} $size con teclado y texto 200%',
        (tester) async {
          viewport(tester, size);
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          addTearDown(tester.view.resetViewInsets);
          final calls = <String>[];
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dioProvider.overrideWithValue(
                  simulatedDio(clinicalReply, calls),
                ),
                registrationSubmitProvider.overrideWithValue((_) async {
                  fail('Datos vacíos no deben enviarse');
                }),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: registration ? const SignUpView() : const SignInView(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = registration
              ? find.byKey(const ValueKey('register-submit'))
              : find.widgetWithText(FilledButton, 'Ingresar');
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(calls, isEmpty);
          expect(
            find.text('El usuario debe tener entre 3 y 50 caracteres.'),
            findsOneWidget,
          );
        },
      );
    }
  }

  for (final config in [
    (const Size(320, 640), 2.0, 180.0),
    (const Size(844, 390), 2.0, 120.0),
    (const Size(1024, 768), 1.0, 240.0),
  ]) {
    for (final form in [
      ('/patients', 'patient-save'),
      ('/vital-signs', 'vital-save'),
      ('/clinical-events', 'event-save'),
      ('/sbar', 'sbar-save'),
      ('/alerts', 'Guardar'),
      ('/reports', 'report-generate'),
      ('/subscriptions', 'checkout-pay'),
    ]) {
      testWidgets(
        'Formulario ${form.$1} ${config.$1} texto ${config.$2} con teclado',
        (tester) async {
          viewport(tester, config.$1);
          tester.view.viewInsets = FakeViewPadding(bottom: config.$3);
          addTearDown(tester.view.resetViewInsets);
          final calls = <String>[];
          final container = ProviderContainer(
            overrides: [
              secureStoreProvider.overrideWithValue(
                SessionStore(actor: fixtures.admin),
              ),
              dioProvider.overrideWithValue(
                simulatedDio(
                  (request) => request.path == '/users'
                      ? [
                          fixtures.nurse.toJson(),
                          fixtures.doctor.toJson(),
                          fixtures.admin.toJson(),
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
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(config.$2)),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          router.go(form.$1);
          await tester.pumpAndSettle();
          final open = form.$1 == '/subscriptions'
              ? find.byKey(const ValueKey('subscription-select-professional'))
              : find.byType(FloatingActionButton);
          await tester.ensureVisible(open);
          await tester.pumpAndSettle();
          await tester.tap(open);
          await tester.pumpAndSettle();
          final submit = form.$1 == '/alerts'
              ? find.widgetWithText(FilledButton, form.$2)
              : find.byKey(ValueKey(form.$2));
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(Form), findsOneWidget);
          expect(
            calls.every((call) => call.startsWith('GET ')),
            isTrue,
            reason: 'Formulario vacío no debe escribir en la API',
          );
        },
      );
    }
  }
}
