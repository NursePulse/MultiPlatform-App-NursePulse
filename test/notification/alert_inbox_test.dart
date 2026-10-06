import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_inbox.dart';

import 'fixtures.dart';

void main() {
  test('baseline counts pending but does not announce historical alerts', () {
    final inbox = AlertInbox(() async {});
    addTearDown(inbox.dispose);
    inbox.receive([alert(), alert(id: '10', status: 'CLOSED')]);
    expect(inbox.state.alerts.map((a) => a.id), ['9']);
    expect(inbox.state.notice, isNull);
    inbox.receive([alert(id: '12'), alert()]);
    expect(inbox.state.notice?.id, '12');
    inbox.dismiss();
    inbox.receive([alert(id: '12'), alert()]);
    expect(inbox.state.notice, isNull);
    // Removed/reappearing and formerly closed IDs are not new notifications.
    inbox.receive([]);
    inbox.receive([alert(id: '12'), alert(id: '10')]);
    expect(inbox.state.notice, isNull);
  });

  test('closing a pending banner removes it and counts attended alerts', () {
    final inbox = AlertInbox(() async {});
    addTearDown(inbox.dispose);
    inbox.receive([]);
    inbox.receive([alert(id: '12'), alert(status: 'ATTENDED')]);
    expect(inbox.state.alerts, hasLength(2));
    expect(inbox.state.notice?.id, '12');
    inbox.receive([
      alert(id: '12', status: 'CLOSED'),
      alert(status: 'ATTENDED'),
    ]);
    expect(inbox.state.notice, isNull);
    expect(inbox.state.alerts.single.id, '9');
  });

  test('refresh never overlaps and pauses until the app resumes', () async {
    var calls = 0;
    final response = Completer<void>();
    final inbox = AlertInbox(() {
      calls++;
      return response.future;
    });
    addTearDown(inbox.dispose);
    final loading = inbox.refresh();
    await inbox.refresh();
    expect(calls, 1);
    response.complete();
    await loading;
    inbox.setActive(false);
    await inbox.refresh();
    expect(calls, 1);
    inbox.setActive(true);
    expect(calls, 2);
  });
}
