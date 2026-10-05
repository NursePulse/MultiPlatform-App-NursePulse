import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/application/audit_notifier.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_page.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';

import 'fixtures.dart';

void main() {
  late FakeAuditApi api;
  late AuditNotifier notifier;
  User? actor;
  var saved = 0, confirmed = 0;
  var disposed = false;
  setUp(() {
    api = FakeAuditApi();
    actor = doctor;
    saved = confirmed = 0;
    disposed = false;
    notifier = AuditNotifier(api, () => actor, (_) async {
      saved++;
      return true;
    }, onExportConfirmed: () => confirmed++);
  });
  tearDown(() {
    if (!disposed) notifier.dispose();
  });

  for (final allowed in [doctor, admin]) {
    test(
      '${allowed.primaryRole} carga página y ordena más reciente primero',
      () async {
        actor = allowed;
        api.pageResult = AuditPage(
          logs: [
            log(id: '1', date: '2025-01-01T12:00:00Z'),
            log(id: '2'),
          ],
          page: 0,
          size: 100,
          totalElements: 102,
          totalPages: 2,
          last: false,
        );
        await notifier.load();
        expect(notifier.state.logs.map((l) => l.id), ['2', '1']);
        expect(notifier.state.totalElements, 102);
        expect(notifier.state.last, isFalse);
        expect(notifier.state.hasLoaded, isTrue);
      },
    );
  }
  for (final forbidden in [
    null,
    nurse,
    const User(id: '1', username: 'unknown.test', roles: ['ROLE_UNKNOWN']),
  ]) {
    test(
      'sin permiso ${forbidden?.username}: cero lecturas y exportaciones',
      () async {
        actor = forbidden;
        await notifier.load();
        await notifier.loadForPatient('1');
        await expectLater(notifier.exportPdf(), throwsFormatException);
        expect(api.pages + api.timelines + api.exports, 0);
        expect(saved, 0);
      },
    );
  }
  for (final id in ['', '0', '-1', '1.2', 'abc']) {
    test('historial inválido $id no llama API', () async {
      await notifier.loadForPatient(id);
      expect(api.timelines, 0);
      expect(notifier.state.error, isNotNull);
    });
  }
  test('historial normalizado y cronológico', () async {
    api.timeline = [log(id: '2'), log(id: '1', date: '2025-01-01T12:00:00Z')];
    await notifier.loadForPatient(' 001 ');
    expect(api.patientId, '1');
    expect(notifier.state.selectedPatientId, '1');
    expect(notifier.state.logs.map((l) => l.id), ['1', '2']);
    expect(notifier.state.totalElements, isNull);
  });
  test(
    'páginas disponibles consultan su índice real y refresh conserva índice',
    () async {
      api.pageResult = const AuditPage(
        logs: [],
        page: 0,
        size: 100,
        totalElements: 150,
        totalPages: 2,
        last: false,
      );
      await notifier.load();
      api.pageResult = const AuditPage(
        logs: [],
        page: 1,
        size: 100,
        totalElements: 150,
        totalPages: 2,
        last: true,
      );
      await notifier.loadPage(1);
      await notifier.reload();
      expect(api.page, 1);
      expect(notifier.state.page, 1);
      expect(notifier.state.last, isTrue);
      await notifier.loadPage(2);
      await notifier.loadPage(-1);
      expect(api.pages, 3);
    },
  );
  test('historial no solicita páginas globales', () async {
    await notifier.loadForPatient('1');
    await notifier.loadPage(1);
    expect(api.pages, 0);
    expect(api.timelines, 1);
  });
  for (final code in [400, 401, 403, 404, 503]) {
    test('recarga $code conserva registros y recupera', () async {
      api.pageResult = AuditPage(logs: [log()], page: 0, size: 100);
      await notifier.load();
      api.failure = httpFailure(code);
      await notifier.reload();
      expect(notifier.state.logs, hasLength(1));
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.loading, isFalse);
      api.failure = null;
      await notifier.reload();
      expect(notifier.state.error, isNull);
    });
  }
  test('primer error no fabrica consulta vacía exitosa', () async {
    api.failure = httpFailure(503);
    await notifier.load();
    expect(notifier.state.hasLoaded, isFalse);
    expect(notifier.state.totalElements, isNull);
    await expectLater(notifier.exportPdf(), throwsFormatException);
    expect(api.exports, 0);
  });
  test(
    'cambio de paciente con error no muestra movimientos del anterior',
    () async {
      api.timeline = [log(patientId: '1')];
      await notifier.loadForPatient('1');
      api.failure = httpFailure(503);
      await notifier.loadForPatient('2');
      expect(notifier.state.selectedPatientId, '2');
      expect(notifier.state.logs, isEmpty);
      expect(notifier.state.hasLoaded, isFalse);
    },
  );
  test('doble recarga comparte solicitud', () async {
    final gate = Completer<AuditPage>();
    api.reading = (_) => gate.future;
    final first = notifier.load(), second = notifier.load();
    expect(api.pages, 1);
    gate.complete(api.pageResult);
    await Future.wait([first, second]);
  });
  test(
    'respuestas atrasadas de otro filtro no sobrescriben la selección',
    () async {
      final gate = Completer<AuditPage>();
      api.reading = (_) => gate.future;
      final pending = notifier.load();
      api.timeline = [log(patientId: '2')];
      await notifier.loadForPatient('2');
      gate.complete(AuditPage(logs: [log()], page: 0, size: 100));
      await pending;
      expect(notifier.state.selectedPatientId, '2');
      expect(notifier.state.logs.single.patientId, '2');
    },
  );
  test('cambio de sesión descarta respuesta', () async {
    final gate = Completer<AuditPage>();
    api.reading = (_) => gate.future;
    final pending = notifier.load();
    actor = admin;
    gate.complete(AuditPage(logs: [log()], page: 0, size: 100));
    await pending;
    expect(notifier.state.logs, isEmpty);
    expect(notifier.state.error, contains('sesión'));
  });
  test('dispose durante lectura no publica ni lanza', () async {
    final gate = Completer<AuditPage>();
    api.reading = (_) => gate.future;
    final pending = notifier.load();
    notifier.dispose();
    disposed = true;
    gate.complete(api.pageResult);
    await expectLater(pending, completes);
  });
  for (final id in [null, '1']) {
    test(
      'exportación usa filtro $id, guarda y recarga auditoría del servidor',
      () async {
        if (id == null) {
          await notifier.load();
        } else {
          await notifier.loadForPatient(id);
        }
        expect(await notifier.exportPdf(), isTrue);
        expect(api.patientId, id);
        expect(saved, 1);
        expect(confirmed, 1);
        expect(api.pages + api.timelines, 2);
        expect(notifier.state.exportNotice, 'PDF guardado.');
        expect(notifier.hasPendingPdf, isFalse);
      },
    );
  }
  for (final code in [400, 401, 403, 503]) {
    test('exportación $code no declara éxito ni guarda archivo', () async {
      await notifier.load();
      api.pdfFailure = httpFailure(code);
      expect(await notifier.exportPdf(), isFalse);
      expect(saved, 0);
      expect(confirmed, 0);
      expect(notifier.state.exportNotice, isNotNull);
      expect(notifier.state.exporting, isFalse);
    });
  }
  for (final cancel in [true, false]) {
    test(
      'guardado ${cancel ? 'cancelado' : 'fallido'} reutiliza PDF sin repetir exportación confirmada',
      () async {
        notifier.dispose();
        var attempts = 0;
        notifier = AuditNotifier(api, () => actor, (bytes) async {
          expect(bytes, pdf);
          attempts++;
          if (attempts == 1) {
            if (cancel) return false;
            throw const FormatException('Destino no disponible');
          }
          return true;
        });
        await notifier.load();
        expect(await notifier.exportPdf(), isFalse);
        expect(notifier.hasPendingPdf, isTrue);
        expect(await notifier.exportPdf(), isTrue);
        expect(api.exports, 1);
        expect(attempts, 2);
      },
    );
  }
  test('cambiar paciente descarta PDF pendiente del filtro anterior', () async {
    notifier.dispose();
    notifier = AuditNotifier(api, () => actor, (_) async => false);
    await notifier.loadForPatient('1');
    await notifier.exportPdf();
    await notifier.loadForPatient('2');
    expect(notifier.hasPendingPdf, isFalse);
    await notifier.exportPdf();
    expect(api.exports, 2);
    expect(api.patientId, '2');
  });
  test(
    'doble exportación y cambio de filtro pendientes no duplican GET',
    () async {
      await notifier.load();
      final gate = Completer<Uint8List>();
      api.exporting = () => gate.future;
      final pending = notifier.exportPdf();
      expect(await notifier.exportPdf(), isFalse);
      await notifier.loadForPatient('2');
      expect(api.timelines, 0);
      gate.complete(pdf);
      expect(await pending, isTrue);
      expect(api.exports, 1);
    },
  );
  test('sesión cambia durante PDF: no guarda documento privado', () async {
    api.pageResult = AuditPage(logs: [log()], page: 0, size: 100);
    await notifier.load();
    final gate = Completer<Uint8List>();
    api.exporting = () => gate.future;
    final pending = notifier.exportPdf();
    actor = nurse;
    gate.complete(pdf);
    expect(await pending, isFalse);
    expect(saved, 0);
    expect(notifier.state.logs, isEmpty);
  });
  test(
    'lectura posterior fallida no repite exportación ni invalida guardado',
    () async {
      await notifier.load();
      api.failure = httpFailure(503);
      expect(await notifier.exportPdf(), isTrue);
      expect(api.exports, 1);
      expect(saved, 1);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.exportNotice, 'PDF guardado.');
    },
  );
}
