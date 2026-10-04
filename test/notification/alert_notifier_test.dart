import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/notification/application/alert_notifier.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert.dart';
import 'package:nurse_pulse_app/features/notification/domain/alert_rules.dart';
import 'package:nurse_pulse_app/features/notification/infrastructure/alert_api.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';

import '../patient/fixtures.dart';
import 'fixtures.dart';

void main() {
  late FakeAlertApi api;
  late AlertNotifier notifier;
  User? user;
  var patients = 0, audits = 0, changes = 0;
  Object? auditError;
  late Future<Patient> Function(String) getPatient;
  Future<AlertWriteReceipt> create({
    String patientId = '1',
    String type = 'CARDIAC',
    String description = ' Alerta ficticia ',
  }) => notifier.create(
    patientId: patientId,
    type: type,
    severity: AlertSeverity.critical,
    description: description,
  );

  setUp(() {
    api = FakeAlertApi();
    user = nurse;
    patients = audits = changes = 0;
    auditError = null;
    getPatient = (id) async {
      patients++;
      return patientFrom(patientCommand(), id: id);
    };
    notifier = AlertNotifier(
      api,
      () => user,
      (id) => getPatient(id),
      audit: (_, _, action, staff) async {
        audits++;
        expect(staff, user);
        expect([
          'ALERT_TRIGGERED',
          'ALERT_ACKNOWLEDGED',
          'UPDATE',
        ], contains(action));
        if (auditError != null) throw auditError!;
      },
      onChanged: (_, _) => changes++,
    );
  });
  tearDown(() {
    if (notifier.mounted) notifier.dispose();
  });

  test('inválidos no consultan catálogos ni escriben', () async {
    for (final id in ['', '0', 'abc', '-1', '1.5']) {
      await expectLater(create(patientId: id), throwsFormatException);
      await expectLater(notifier.attend(id), throwsFormatException);
      user = doctor;
      await expectLater(notifier.close(id), throwsFormatException);
      user = nurse;
    }
    for (final text in ['', ' ', 'x' * 256]) {
      await expectLater(create(description: text), throwsFormatException);
    }
    await expectLater(create(type: 'UNKNOWN'), throwsFormatException);
    expect(patients + api.writes + api.detailReads, 0);
  });
  for (final staff in [nurse, doctor, admin]) {
    test('${staff.username}: POST válido trim, paciente y auditoría', () async {
      user = staff;
      final result = await create(
        patientId: ' 001 ',
        description: ' ${'x' * 255} ',
      );
      expect(result.alert!.id, '9');
      expect(api.sent!['patientId'], '1');
      expect(api.sent!['description'], 'x' * 255);
      expect(api.sent!['triggeredBy'], alertDefaultActor);
      expect(patients, 1);
      expect(audits, 1);
      expect(changes, 1);
      expect(notifier.state.alerts.single.id, '9');
      expect(notifier.state.saving, isFalse);
    });
    test('${staff.username} atiende con su identidad de sesión', () async {
      user = staff;
      await notifier.attend(' 009 ');
      expect(api.attends, 1);
      expect(api.sent!['attendedBy'], staff.username);
      expect(notifier.state.alerts.single.status, AlertStatus.attended);
      expect(audits, 1);
      expect(changes, 1);
    });
  }
  for (final staff in [doctor, admin]) {
    test('${staff.username} cierra una atendida con nota web', () async {
      user = staff;
      api.current = alert(status: 'ATTENDED');
      await notifier.close('9');
      expect(api.closes, 1);
      expect(api.sent!['closedBy'], staff.username);
      expect(api.sent!['resolutionNotes'], alertClosingNotes);
      expect(notifier.state.alerts.single.status, AlertStatus.closed);
    });
  }
  test('Nurse no cierra ni consulta detalle de cierre', () async {
    await expectLater(notifier.close('9'), throwsFormatException);
    expect(api.writes + api.detailReads, 0);
  });
  test('sin sesión/rol no se llama ninguna API', () async {
    for (final staff in [
      null,
      const User(id: '7', username: 'unknown', roles: []),
    ]) {
      user = staff;
      await expectLater(create(), throwsFormatException);
      await expectLater(notifier.attend('9'), throwsFormatException);
      await expectLater(notifier.close('9'), throwsFormatException);
      await expectLater(notifier.loadForPatient('1'), throwsFormatException);
      await notifier.load();
      expect(notifier.state.error, isNotNull);
    }
    expect(patients + api.writes + api.detailReads + api.reads, 0);
  });
  test('notas inválidas no llaman API', () async {
    user = doctor;
    for (final text in ['', ' ', 'x' * 256]) {
      await expectLater(
        notifier.close('9', resolutionNotes: text),
        throwsFormatException,
      );
    }
    expect(api.writes + api.detailReads, 0);
  });
  for (final status in ['ATTENDED', 'CLOSED']) {
    test('atender $status refresca estado sin PATCH', () async {
      api.current = alert(status: status);
      await expectLater(notifier.attend('9'), throwsFormatException);
      expect(api.attends, 0);
      expect(audits, 0);
      expect(notifier.state.alerts.single.status.wireValue, status);
      expect(notifier.state.saving, isFalse);
    });
  }
  for (final status in ['OPEN', 'CLOSED']) {
    test('cerrar $status no hace PATCH conforme al flujo web', () async {
      user = doctor;
      api.current = alert(status: status);
      await expectLater(notifier.close('9'), throwsFormatException);
      expect(api.closes, 0);
      expect(audits, 0);
    });
  }
  test('paciente ausente o distinto no genera POST', () async {
    getPatient = (_) async => throw httpFailure(404);
    await expectLater(create(), throwsA(isA<DioException>()));
    getPatient = (_) async => patientFrom(patientCommand(), id: '7');
    await expectLater(create(), throwsFormatException);
    expect(api.posts, 0);
    expect(notifier.state.saving, isFalse);
  });
  test('sesión cambia durante catálogo: no POST', () async {
    getPatient = (id) async {
      user = doctor;
      return patientFrom(patientCommand(), id: id);
    };
    await expectLater(create(), throwsFormatException);
    expect(api.posts, 0);
  });
  test('permiso cambia durante detalle: no PATCH', () async {
    user = doctor;
    api.detail = () async {
      user = nurse;
      return alert(status: 'ATTENDED');
    };
    await expectLater(notifier.close('9'), throwsFormatException);
    expect(api.closes, 0);
  });
  for (final operation in ['create', 'attend', 'close']) {
    test('doble $operation bloqueado durante escritura', () async {
      user = doctor;
      api.current = alert(status: operation == 'close' ? 'ATTENDED' : 'OPEN');
      final gate = Completer<AlertWriteReceipt>();
      api.writing = () => gate.future;
      Future<void> write() async {
        if (operation == 'create') {
          await create();
        } else if (operation == 'attend') {
          await notifier.attend('9');
        } else {
          await notifier.close('9');
        }
      }

      final pending = write();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.saving, isTrue);
      await expectLater(write(), throwsFormatException);
      expect(api.writes, 1);
      gate.complete(AlertWriteReceipt(id: '9', alert: alert()));
      await pending;
      expect(notifier.state.saving, isFalse);
    });
    for (final code in [400, 401, 403, 409, 503]) {
      test('$operation HTTP $code no se reintenta y libera bloqueo', () async {
        user = doctor;
        api.current = alert(status: operation == 'close' ? 'ATTENDED' : 'OPEN');
        api.failure = httpFailure(code);
        final Future<Object?> pending = operation == 'create'
            ? create()
            : operation == 'attend'
            ? notifier.attend('9')
            : notifier.close('9');
        await expectLater(pending, throwsA(isA<DioException>()));
        expect(api.writes, 1);
        expect(audits, 0);
        expect(notifier.state.saving, isFalse);
        expect(notifier.state.confirmedActions, isEmpty);
      });
    }
  }
  test('fallo de conexión no fabrica alerta', () async {
    api.failure = DioException(
      requestOptions: RequestOptions(path: '/alerts'),
      type: DioExceptionType.connectionError,
    );
    await expectLater(create(), throwsA(isA<DioException>()));
    expect(api.posts, 1);
    expect(notifier.state.alerts, isEmpty);
  });
  test(
    'POST confirmado sin detalle muestra aviso y no fabrica datos',
    () async {
      api.receipt = AlertWriteReceipt(
        id: '9',
        readError: StateError('cuerpo inválido'),
      );
      await create();
      expect(api.posts, 1);
      expect(audits, 1);
      expect(changes, 1);
      expect(notifier.state.alerts, isEmpty);
      expect(notifier.state.warning, contains('no repitas'));
    },
  );
  for (final closing in [false, true]) {
    test(
      'PATCH confirmado sin detalle no se repite: cierre=$closing',
      () async {
        user = doctor;
        api.current = alert(status: closing ? 'ATTENDED' : 'OPEN');
        api.receipt = AlertWriteReceipt(
          id: '9',
          readError: StateError('detalle'),
        );
        if (closing) {
          await notifier.close('9');
          await notifier.close('9');
        } else {
          await notifier.attend('9');
          await notifier.attend('9');
        }
        expect(api.writes, 1);
        expect(audits, 1);
        expect(notifier.state.warning, contains('no repitas'));
        expect(
          notifier.state.alerts.single.status.wireValue,
          closing ? 'ATTENDED' : 'OPEN',
        );
      },
    );
  }
  test('auditoría fallida no rechaza ni repite creación confirmada', () async {
    auditError = StateError('auditoría simulada');
    final result = await create();
    expect(result.alert, isNotNull);
    expect(api.posts, 1);
    expect(notifier.state.warning, contains('auditoría'));
    expect(changes, 1);
  });
  test('listado ordenado por fecha real; sin fecha al final', () async {
    api.alerts = [
      alert(id: '1', date: null),
      alert(id: '2', date: '2026-10-03T12:00:00'),
      alert(id: '3'),
    ];
    await notifier.load();
    expect(notifier.state.alerts.map((a) => a.id), ['3', '2', '1']);
    expect((await notifier.loadForPatient(' 001 ')).map((a) => a.id), [
      '3',
      '2',
      '1',
    ]);
  });
  test('listado fallido conserva datos; recargar recupera', () async {
    api.alerts = [alert()];
    await notifier.load();
    api.readFailure = httpFailure(503);
    await notifier.load();
    expect(notifier.state.alerts, hasLength(1));
    expect(notifier.state.error, contains('503'));
    expect(notifier.state.loading, isFalse);
    api.readFailure = null;
    await notifier.load();
    expect(notifier.state.error, isNull);
  });
  test('carga antigua no borra creación confirmada', () async {
    final gate = Completer<List<Alert>>();
    api.loading = () => gate.future;
    final pending = notifier.load();
    await create();
    gate.complete([]);
    await pending;
    expect(notifier.state.alerts.single.id, '9');
    expect(notifier.state.loading, isFalse);
  });
  test('ID inválido de historial no consulta', () async {
    await expectLater(notifier.loadForPatient('abc'), throwsFormatException);
    expect(api.reads, 0);
  });
}
