import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_inbox.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/notification/infrastructure/alert_api.dart';

import 'fixtures.dart';

void main() {
  test('inbox and seen IDs reset between accounts; forbidden/background reads stop', () async {
    final actorProvider = StateProvider<User?>((ref) => nurse);
    final api = FakeAlertApi()..alerts = [alert()];
    final container = ProviderContainer(
      overrides: [
        alertUserProvider.overrideWith((ref) => ref.watch(actorProvider)),
        alertApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.listen(alertInboxProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(container.read(alertInboxProvider).alerts.single.id, '9');
    api.alerts = [alert(id: '12'), alert()];
    await container.read(alertInboxProvider.notifier).refresh();
    expect(container.read(alertInboxProvider).notice?.id, '12');

    api.alerts = [alert(id: '42')];
    container.read(actorProvider.notifier).state = doctor;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(alertInboxProvider).alerts.single.id, '42');
    expect(container.read(alertInboxProvider).notice, isNull);

    container.read(alertAppActiveProvider.notifier).state = false;
    final count = api.reads;
    container.read(actorProvider.notifier).state = admin;
    await Future<void>.delayed(Duration.zero);
    expect(api.reads, count);
    expect(container.read(alertInboxProvider).alerts, isEmpty);

    container.read(alertAppActiveProvider.notifier).state = true;
    container.read(actorProvider.notifier).state = const User(
      id: '100',
      username: 'unknown.test',
      roles: ['UNKNOWN'],
    );
    await Future<void>.delayed(Duration.zero);
    await container.read(alertInboxProvider.notifier).refresh();
    expect(api.reads, count);
    expect(container.read(alertCanManageProvider), isFalse);
    expect(container.read(alertInboxProvider).notice, isNull);
    container.read(actorProvider.notifier).state = null;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(alertInboxProvider).alerts, isEmpty);
    expect(api.writes, 0);
  });
}
