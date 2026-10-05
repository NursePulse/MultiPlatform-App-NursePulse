import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/router/app_router.dart';
import 'package:nurse_pulse_app/core/theme/app_theme.dart';
import 'package:nurse_pulse_app/features/iam/application/auth_notifier.dart';
import 'package:nurse_pulse_app/features/iam/application/view_mode_notifier.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';

import '../dashboard/fixtures.dart' as dash;
import 'session_isolation_test.dart'
    show SessionStore, clinicalReply, simulatedDio;

void main() {
  for (final actor in [dash.nurse, dash.doctor, dash.admin]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'navegación completa ${actor.primaryRole}, texto ${scale * 100}% y cierre de sesión',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final calls = <String>[];
          var localReads = 0;
          final container = ProviderContainer(
            overrides: [
              secureStoreProvider.overrideWithValue(SessionStore(actor: actor)),
              dioProvider.overrideWithValue(simulatedDio(clinicalReply, calls)),
              reportLocalStoreProvider.overrideWithValue(
                ReportLocalStore(
                  read: () async {
                    localReads++;
                    return null;
                  },
                  write: (_) async {},
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
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/dashboard');
          // Un modo visual distinto no concede permisos ni cambia el perfil móvil.
          container
              .read(viewModeProvider.notifier)
              .setMode(actor == dash.nurse ? ViewMode.admin : ViewMode.nurse);
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
          final drawerList = find.descendant(
            of: find.byType(Drawer),
            matching: find.byType(ListView),
          );
          if (actor != dash.nurse) {
            await tester.scrollUntilVisible(
              find.text('Reportes'),
              200,
              scrollable: find.descendant(
                of: drawerList,
                matching: find.byType(Scrollable),
              ),
            );
          }
          expect(
            find.text('Reportes'),
            actor == dash.nurse ? findsNothing : findsOneWidget,
          );
          if (actor != dash.nurse) {
            await tester.scrollUntilVisible(
              find.text('Auditoría'),
              200,
              scrollable: find.descendant(
                of: drawerList,
                matching: find.byType(Scrollable),
              ),
            );
          }
          expect(
            find.text('Auditoría'),
            actor == dash.nurse ? findsNothing : findsOneWidget,
          );
          if (actor == dash.admin) {
            await tester.scrollUntilVisible(
              find.text('Usuarios'),
              200,
              scrollable: find.descendant(
                of: drawerList,
                matching: find.byType(Scrollable),
              ),
            );
          }
          expect(
            find.text('Usuarios'),
            actor == dash.admin ? findsOneWidget : findsNothing,
          );
          Navigator.of(tester.element(find.byType(Drawer))).pop();
          await tester.pumpAndSettle();

          for (final path in [
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
            final before = calls.length;
            final allowed = switch (path) {
              '/reports' || '/audit' => actor != dash.nurse,
              '/users' => actor == dash.admin,
              _ => true,
            };
            router.go(path);
            await tester.pumpAndSettle();
            expect(
              router.routeInformationProvider.value.uri.path,
              allowed ? path : '/dashboard',
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$path/${actor.primaryRole}/$scale',
            );
            if (!allowed) {
              expect(
                calls
                    .skip(before)
                    .any(
                      (c) => c.contains('/users') || c.contains('/audit-logs'),
                    ),
                isFalse,
              );
            }
          }
          if (actor == dash.nurse) {
            expect(localReads, 0);
            expect(calls.any((c) => c.contains('/audit-logs')), isFalse);
          }
          expect(calls.every((c) => c.startsWith('GET ')), isTrue);
          expect(
            calls.any(
              (c) =>
                  c.contains('/reports') ||
                  c == 'GET /handovers' ||
                  c.contains('/dashboard/summary'),
            ),
            isFalse,
          );
          await container.read(authNotifierProvider.notifier).signOut();
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/sign-in');
          final afterSignOut = calls.length;
          router.go('/patients/1/monitoring');
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/sign-in');
          expect(calls.skip(afterSignOut), isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
