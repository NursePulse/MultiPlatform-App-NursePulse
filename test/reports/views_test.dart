import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/report/application/report_notifier.dart';
import 'package:nurse_pulse_app/features/report/presentation/report_list_view.dart';

import 'fixtures.dart';

Future<void> mount(
  WidgetTester tester,
  MemoryReports memory,
  Sources sources, {
  User? actor = doctor,
  AuditCalls? audit,
  double scale = 1,
}) async {
  final n = notifier(memory, sources, actor: actor, audit: audit);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        reportUserProvider.overrideWithValue(actor),
        reportClockProvider.overrideWithValue(() => now),
        reportNotifierProvider.overrideWith((ref) {
          Future.microtask(n.load);
          return n;
        }),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const ReportListView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('report-new')));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('report-generate')));
  await tester.tap(find.byKey(const ValueKey('report-generate')));
  await tester.pumpAndSettle();
}

void main() {
  for (final actor in [null, nurse]) {
    testWidgets(
      'sin permiso no lee reportes ni muestra generación ${actor?.username}',
      (tester) async {
        final memory = MemoryReports(), sources = Sources();
        await mount(tester, memory, sources, actor: actor);
        expect(find.byKey(const ValueKey('report-new')), findsNothing);
        expect(memory.reads, 0);
        expect(sources.calls, isEmpty);
        expect(
          find.text('Solo Doctor o Admin pueden consultar y generar reportes.'),
          findsOneWidget,
        );
      },
    );
  }
  for (final actor in [doctor, admin]) {
    testWidgets('${actor.primaryRole} genera, abre detalle y restaura lista', (
      tester,
    ) async {
      final memory = MemoryReports(), sources = Sources();
      await mount(tester, memory, sources, actor: actor);
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('report-title')),
        ' Reporte ficticio ',
      );
      await submit(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Reporte ficticio'), findsOneWidget);
      expect(find.text('1 reportes'), findsOneWidget);
      expect(memory.writes, 1);
      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Actividad registrada: 0'), findsOneWidget);
      expect(find.text('Sin alertas activas'), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await mount(tester, memory, sources, actor: actor);
      expect(find.text('Reporte ficticio'), findsOneWidget);
      expect(memory.writes, 1);
    });
  }
  testWidgets('título vacío o espacios no consulta API', (tester) async {
    final memory = MemoryReports(), sources = Sources();
    await mount(tester, memory, sources);
    await openForm(tester);
    await submit(tester);
    expect(find.text('El título es obligatorio.'), findsOneWidget);
    expect(sources.calls, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('report-title')), '   ');
    await submit(tester);
    expect(memory.writes, 0);
    expect(sources.calls, isEmpty);
  });
  for (final field in ['start', 'end']) {
    testWidgets('fecha $field obligatoria antes de consultar API', (
      tester,
    ) async {
      final memory = MemoryReports(), sources = Sources();
      await mount(tester, memory, sources);
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('report-title')),
        'Reporte ficticio',
      );
      await tester.tap(find.byKey(ValueKey('report-clear-$field')));
      await tester.pumpAndSettle();
      await submit(tester);
      expect(find.text('Selecciona la fecha.'), findsOneWidget);
      expect(sources.calls, isEmpty);
      expect(memory.writes, 0);
    });
  }
  testWidgets('rango invertido conserva título y bloquea generación', (
    tester,
  ) async {
    final sources = Sources();
    await mount(tester, MemoryReports(), sources);
    await openForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('report-title')),
      'Reporte ficticio',
    );
    final dateFields = find.byType(TextFormField);
    await tester.tap(dateFields.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5').last);
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await submit(tester);
    expect(
      find.text('La fecha inicial no puede ser posterior a la final.'),
      findsWidgets,
    );
    expect(sources.calls, isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('report-title')))
          .controller!
          .text,
      'Reporte ficticio',
    );
  });
  testWidgets(
    'fallo pacientes conserva formulario y datos para reintento explícito',
    (tester) async {
      final memory = MemoryReports(),
          sources = Sources()
            ..failures['patients'] = StateError('Error simulado');
      await mount(tester, memory, sources);
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('report-title')),
        'Reporte ficticio',
      );
      await submit(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byKey(const ValueKey('report-form-error')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('report-title')))
            .controller!
            .text,
        'Reporte ficticio',
      );
      expect(memory.writes, 0);
      sources.failures.clear();
      await submit(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(memory.writes, 1);
    },
  );
  testWidgets(
    'auditoría fallida conserva reporte y cierra formulario sin permitir repetir por error',
    (tester) async {
      final memory = MemoryReports();
      await mount(
        tester,
        memory,
        Sources(),
        audit: AuditCalls()..failure = StateError('Error simulado'),
      );
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('report-title')),
        'Reporte ficticio',
      );
      await submit(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('report-warning')), findsOneWidget);
      expect(find.text('Reporte ficticio'), findsOneWidget);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(memory.writes, 1);
    },
  );
  testWidgets(
    'doble tap bloquea campos, cancelación y salida; un solo reporte',
    (tester) async {
      final memory = MemoryReports(),
          sources = Sources()..patientGate = Completer<List<Patient>>();
      await mount(tester, memory, sources);
      await openForm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('report-title')),
        'Reporte ficticio',
      );
      await tester.tap(find.byKey(const ValueKey('report-generate')));
      await tester.tap(find.byKey(const ValueKey('report-generate')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('report-generate')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('report-cancel')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('report-title')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<PopScope>(
              find
                  .ancestor(
                    of: find.byType(AlertDialog),
                    matching: find.byType(PopScope),
                  )
                  .first,
            )
            .canPop,
        isFalse,
      );
      sources.patientGate!.complete([patient()]);
      await tester.pumpAndSettle();
      expect(memory.writes, 1);
    },
  );
  testWidgets(
    'corrupción deja lista vacía y fallo real de lectura ofrece reintento',
    (tester) async {
      final memory = MemoryReports()..raw = '{broken';
      await mount(tester, memory, Sources());
      expect(find.text('Aún no generaste ningún reporte.'), findsOneWidget);
      memory.readFailure = StateError('Error simulado');
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-retry')), findsOneWidget);
      expect(find.text('Aún no generaste ningún reporte.'), findsNothing);
      memory.readFailure = null;
      await tester.tap(find.byKey(const ValueKey('report-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Aún no generaste ningún reporte.'), findsOneWidget);
    },
  );
  testWidgets(
    '320px y texto ampliado admiten formulario y detalle sin desbordamiento',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final memory = MemoryReports();
      await memory.store.add(report());
      await mount(tester, memory, Sources(), scale: 2);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ver detalle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await openForm(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
