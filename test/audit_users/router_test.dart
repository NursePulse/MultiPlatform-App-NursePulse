import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/router/app_router.dart';

import '../iam/session_test.dart' show MemoryStore;
import 'fixtures.dart';

void main() {
  for (final actor in [nurse, doctor, admin]) {
    for (final target in ['/audit', '/users']) {
      testWidgets('ruta $target aplica permisos de ${actor.primaryRole}', (
        tester,
      ) async {
        final paths = <String>[];
        final container = ProviderContainer(
          overrides: [
            secureStoreProvider.overrideWithValue(
              MemoryStore(role: actor.primaryRole),
            ),
            dioProvider.overrideWithValue(
              mockDio((request) => [], paths: paths),
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
        final before = paths.length;
        final allowed = target == '/audit' ? actor != nurse : actor == admin;
        router.go(target);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          allowed ? target : '/dashboard',
        );
        if (!allowed) {
          expect(paths.skip(before), isEmpty);
        } else {
          expect(
            paths.skip(before),
            contains('GET ${target == '/audit' ? '/audit-logs' : '/users'}'),
          );
          expect(
            find.text(
              target == '/audit'
                  ? 'No hay movimientos de auditoría.'
                  : 'No hay usuarios registrados.',
            ),
            findsOneWidget,
          );
        }
        expect(paths.every((p) => p.startsWith('GET ')), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
