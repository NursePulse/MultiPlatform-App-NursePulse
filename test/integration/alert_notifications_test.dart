import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/core/localization/locale_notifier.dart';
import 'package:nurse_pulse_app/core/network/dio_client.dart';
import 'package:nurse_pulse_app/core/router/app_router.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_inbox.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/notification/presentation/alert_detail_dialog.dart';
import 'package:nurse_pulse_app/main.dart';

import '../notification/fixtures.dart' as fixture;
import 'responsive_ui_test.dart' show viewport;
import 'session_isolation_test.dart'
    show SessionStore, clinicalReply, simulatedDio;
import 'ui_role_locale_test.dart' show MemoryLocaleStore;

void main() {
  for (final language in ['es', 'en']) {
    testWidgets(
      'new banner opens exact alert; inbox is read only ($language)',
      (tester) async {
        viewport(tester, const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final calls = <String>[];
        var snapshot = [fixture.alertJson()];
        final container = ProviderContainer(
          overrides: [
            secureStoreProvider.overrideWithValue(SessionStore()),
            localeStoreProvider.overrideWithValue(
              MemoryLocaleStore()..saved = language,
            ),
            dioProvider.overrideWithValue(
              simulatedDio((request) {
                if (request.path == '/alerts') return snapshot;
                if (request.path == '/alerts/12') {
                  return fixture.alertJson(id: '12');
                }
                return clinicalReply(request);
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
        expect(find.byKey(const ValueKey('new-alert-banner')), findsNothing);
        expect(container.read(alertInboxProvider).alerts, hasLength(1));

        snapshot = [fixture.alertJson(id: '12'), fixture.alertJson()];
        final refresh = container.read(alertInboxProvider.notifier).refresh();
        await tester.pumpAndSettle();
        await refresh;
        expect(find.byKey(const ValueKey('new-alert-banner')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('new-alert-banner')));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/alerts');
        expect(
          router.routeInformationProvider.value.uri.queryParameters['alert'],
          '12',
        );
        expect(find.byType(AlertDetailDialog), findsOneWidget);
        expect(calls, contains('GET /alerts/12'));
        expect(container.read(alertInboxProvider).notice, isNull);
        await tester.tap(find.text(language == 'es' ? 'Volver' : 'Back'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('alert-notifications')));
        await tester.pumpAndSettle();
        final entry = find.byKey(const ValueKey('notification-alert-12'));
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDetailDialog), findsOneWidget);
        expect(calls.every((call) => call.startsWith('GET ')), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'polling pauses in background, resumes and preserves snapshot on failure',
    (tester) async {
      final calls = <String>[];
      var fail = false;
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(SessionStore()),
          localeStoreProvider.overrideWithValue(MemoryLocaleStore()),
          dioProvider.overrideWithValue(
            simulatedDio((request) {
              if (request.path == '/alerts' && fail) {
                throw fixture.httpFailure(503);
              }
              return clinicalReply(request);
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
      final count = calls.where((call) => call == 'GET /alerts').length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'GET /alerts'), hasLength(count));
      fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call == 'GET /alerts'),
        hasLength(count + 1),
      );
      expect(container.read(alertInboxProvider).alerts, hasLength(1));
      expect(container.read(alertInboxProvider).notice, isNull);
      expect(container.read(alertNotifierProvider).error, isNull);
      fail = false;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call == 'GET /alerts'),
        hasLength(count + 2),
      );
      expect(calls.every((call) => call.startsWith('GET ')), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
