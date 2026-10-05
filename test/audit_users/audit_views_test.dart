import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/application/audit_notifier.dart';
import 'package:nurse_pulse_app/features/audit/domain/audit_page.dart';
import 'package:nurse_pulse_app/features/audit/infrastructure/audit_api.dart';
import 'package:nurse_pulse_app/features/audit/infrastructure/audit_pdf_saver.dart';
import 'package:nurse_pulse_app/features/audit/presentation/audit_log_list_view.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/infrastructure/patient_api.dart';

import '../dashboard/fixtures.dart' show patient;
import '../patient/fake_patient_api.dart';
import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  FakeAuditApi api, {
  User? actor = doctor,
  AuditPdfSaver? save,
  FakePatientApi? patients,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        auditApiProvider.overrideWithValue(api),
        auditUserProvider.overrideWithValue(actor),
        auditPdfSaverProvider.overrideWithValue(save ?? (_) async => true),
        patientApiProvider.overrideWithValue(patients ?? FakePatientApi()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AuditLogListView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final actor in [null, nurse]) {
    testWidgets('sin permiso no consulta auditoría, pacientes ni exporta', (
      tester,
    ) async {
      final api = FakeAuditApi();
      var catalogs = 0;
      final patients = FakePatientApi()
        ..loading = () async {
          catalogs++;
          return [];
        };
      await mount(tester, api, actor: actor, patients: patients);
      expect(api.pages, 0);
      expect(catalogs, 0);
      expect(find.byKey(const ValueKey('audit-export')), findsNothing);
      expect(
        find.text('Solo Doctor o Admin pueden consultar Auditoría.'),
        findsOneWidget,
      );
    });
  }
  for (final actor in [doctor, admin]) {
    testWidgets('${actor.primaryRole} ve descripción, orden y total real', (
      tester,
    ) async {
      final api = FakeAuditApi()
        ..pageResult = AuditPage(
          logs: [
            log(
              id: '1',
              metadata: {'description': 'Primero'},
              date: '2026-10-03T12:00:00Z',
            ),
            log(id: '2', metadata: {'description': 'Segundo'}),
          ],
          page: 0,
          size: 100,
          totalElements: 2,
          totalPages: 1,
        );
      await mount(tester, api, actor: actor);
      expect(find.text('2 movimientos consultados'), findsOneWidget);
      expect(find.text('2 movimientos en total'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Segundo')).dy,
        lessThan(tester.getTopLeft(find.text('Primero')).dy),
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('audit-next')))
            .onPressed,
        isNull,
      );
    });
  }
  testWidgets(
    'paginación consulta la página solicitada y conserva el filtro al refrescar',
    (tester) async {
      final api = FakeAuditApi()
        ..reading = (page) async => AuditPage(
          logs: [log(id: '${page + 1}')],
          page: page,
          size: 100,
          totalElements: 101,
          totalPages: 2,
          last: page == 1,
        );
      await mount(tester, api);
      await tester.ensureVisible(find.byKey(const ValueKey('audit-next')));
      await tester.tap(find.byKey(const ValueKey('audit-next')));
      await tester.pumpAndSettle();
      expect(api.page, 1);
      expect(find.text('Página 2 de 2'), findsOneWidget);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(api.page, 1);
      expect(api.pages, 3);
    },
  );
  testWidgets('selección de paciente carga timeline y refresca ese ID', (
    tester,
  ) async {
    final api = FakeAuditApi()
      ..timeline = [
        log(id: '2', patientId: '1'),
        log(id: '1', patientId: '1', date: '2026-10-03T12:00:00Z'),
      ];
    await mount(
      tester,
      api,
      patients: FakePatientApi()..patients = [patient()],
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(patient().fullName).last);
    await tester.pumpAndSettle();
    expect(api.patientId, '1');
    expect(api.timelines, 1);
    expect(
      find.text('Historial del paciente: del más antiguo al más reciente.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('audit-next')), findsNothing);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(api.timelines, 2);
    expect(api.patientId, '1');
  });
  testWidgets(
    'cancelar guardado conserva PDF y reintenta solo destino nativo',
    (tester) async {
      final api = FakeAuditApi();
      var saves = 0;
      await mount(tester, api, save: (_) async => ++saves > 1);
      await tester.tap(find.byKey(const ValueKey('audit-export')));
      await tester.pumpAndSettle();
      expect(api.exports, 1);
      expect(find.text('Guardar PDF pendiente'), findsOneWidget);
      expect(
        find.text('Guardado cancelado. Puedes elegir un destino de nuevo.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('audit-export')));
      await tester.pumpAndSettle();
      expect(api.exports, 1);
      expect(saves, 2);
      expect(find.text('PDF guardado.'), findsOneWidget);
    },
  );
  testWidgets('doble tap exporta una vez y bloquea filtro hasta terminar', (
    tester,
  ) async {
    final gate = Completer<Uint8List>();
    final api = FakeAuditApi()..exporting = () => gate.future;
    await mount(tester, api);
    await tester.tap(find.byKey(const ValueKey('audit-export')));
    await tester.tap(find.byKey(const ValueKey('audit-export')));
    await tester.pump();
    expect(api.exports, 1);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('audit-export')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged,
      isNull,
    );
    gate.complete(pdf);
    await tester.pumpAndSettle();
    expect(find.text('PDF guardado.'), findsOneWidget);
  });
  testWidgets('fallo PDF no muestra éxito y admite reintento explícito', (
    tester,
  ) async {
    final api = FakeAuditApi()..pdfFailure = httpFailure(503);
    var saves = 0;
    await mount(
      tester,
      api,
      save: (_) async {
        saves++;
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('audit-export')));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('PDF guardado.'), findsNothing);
    expect(find.byKey(const ValueKey('audit-export-notice')), findsOneWidget);
    api.pdfFailure = null;
    await tester.tap(find.byKey(const ValueKey('audit-export')));
    await tester.pumpAndSettle();
    expect(api.exports, 2);
    expect(saves, 1);
  });
  testWidgets(
    'error de refresco conserva movimientos y catálogo falla independientemente',
    (tester) async {
      final api = FakeAuditApi()
        ..pageResult = AuditPage(
          logs: [log(metadata: 'Movimiento ficticio')],
          page: 0,
          size: 100,
        );
      await mount(
        tester,
        api,
        patients: FakePatientApi()..failure = httpFailure(503),
      );
      expect(find.text('Movimiento ficticio'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('audit-patients-retry')),
        findsOneWidget,
      );
      api.failure = httpFailure(503);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Movimiento ficticio'), findsOneWidget);
      expect(
        find.text('Se muestran los datos de la última consulta completada.'),
        findsOneWidget,
      );
      api.failure = null;
      await tester.tap(find.byKey(const ValueKey('audit-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('audit-retry')), findsNothing);
    },
  );
  testWidgets(
    'error inicial admite reintento sin inventar un listado vacío exitoso',
    (tester) async {
      final api = FakeAuditApi()..failure = httpFailure(403);
      await mount(tester, api);
      expect(find.text('No hay movimientos de auditoría.'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('audit-export')))
            .onPressed,
        isNull,
      );
      api.failure = null;
      await tester.tap(find.byKey(const ValueKey('audit-retry')));
      await tester.pumpAndSettle();
      expect(find.text('No hay movimientos de auditoría.'), findsOneWidget);
    },
  );
  testWidgets(
    '320px y texto ampliado admiten movimientos extensos sin desbordar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeAuditApi()
        ..pageResult = AuditPage(
          logs: [
            log(
              metadata: 'Descripción ficticia extensa para lectura accesible en una pantalla pequeña.',
            ),
          ],
          page: 0,
          size: 100,
          totalElements: 1,
          totalPages: 1,
        );
      await mount(tester, api, scale: 2);
      expect(tester.takeException(), isNull);
    },
  );
}
