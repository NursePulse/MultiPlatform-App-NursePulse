import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/router/app_router.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';

import '../iam/session_test.dart' show MemoryStore;
import 'fixtures.dart';

void main() {
  for (final actor in [nurse, doctor, admin]) {
    testWidgets(
      'ruta y menú Reportes ${actor.primaryRole} respetan el rol real',
      (tester) async {
        final paths = <String>[];
        final container = ProviderContainer(
          overrides: [
            secureStoreProvider.overrideWithValue(
              MemoryStore(role: actor.primaryRole),
            ),
            reportLocalStoreProvider.overrideWithValue(
              ReportLocalStore(read: () async => null, write: (_) async {}),
            ),
            dioProvider.overrideWithValue(
              mockDio((request) {
                if (request.path == '/reports') {
                  throw StateError('Reportes debe ser local.');
                }
                return [];
              }, paths: paths),
            ),
          ],
        );
        addTearDown(container.dispose);
        final router = container.read(appRouterProvider);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        expect(
          find.text('Reportes'),
          actor == nurse ? findsNothing : findsOneWidget,
        );
        router.go('/reports');
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          actor == nurse ? '/dashboard' : '/reports',
        );
        expect(paths.where((path) => path == 'GET /reports'), isEmpty);
        if (actor != nurse) {
          expect(find.text('Aún no generaste ningún reporte.'), findsOneWidget);
        }
        expect(paths.every((p) => p.startsWith('GET ')), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
