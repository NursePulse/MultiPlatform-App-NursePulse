import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient_rules.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_effects.dart';
import 'package:nurse_pulse_app/features/vital_sign/application/vital_sign_notifier.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign.dart';
import 'package:nurse_pulse_app/features/vital_sign/domain/vital_sign_rules.dart';
import 'package:nurse_pulse_app/features/vital_sign/infrastructure/vital_sign_api.dart';
import 'package:nurse_pulse_app/features/vital_sign/presentation/vital_sign_form_sheet.dart';
import 'package:nurse_pulse_app/features/vital_sign/presentation/vital_sign_list_view.dart';

import 'package:nurse_pulse_app/features/patient/infrastructure/patient_api.dart';

import 'patient_fixture.dart';

const nurse = User(id: '2', username: 'nurse.test', roles: [kRoleNurse]);

RecordVitalSignCommand vitalCommand({
  String patientId = '1',
  String nurseId = '999',
  num heart = 78,
  num respiratory = 18,
  num systolic = 120,
  num diastolic = 80,
  num oxygen = 98,
  num temperature = 36.5,
}) => RecordVitalSignCommand(
  patientId: patientId,
  nurseId: nurseId,
  heartRate: heart,
  respiratoryRate: respiratory,
  systolicPressure: systolic,
  diastolicPressure: diastolic,
  oxygenSaturation: oxygen,
  temperature: temperature,
);

VitalSign vital({
  String id = '1',
  RiskLevel risk = RiskLevel.low,
  DateTime? at,
  RecordVitalSignCommand? command,
}) {
  final c = command ?? vitalCommand(nurseId: nurse.id);

  return VitalSign(
    id: id,
    patientId: c.patientId,
    nurseId: c.nurseId,
    heartRate: c.heartRate,
    respiratoryRate: c.respiratoryRate,
    systolic: c.systolicPressure,
    diastolic: c.diastolicPressure,
    oxygenSaturation: c.oxygenSaturation,
    temperature: c.temperature,
    riskLevel: risk,
    recordedAt: at ?? DateTime.utc(2026, 10, 4),
  );
}

class FakeVitalApi extends VitalSignApi {
  FakeVitalApi() : super(Dio());

  List<VitalSign> records = [];
  Object? failure;
  int writes = 0;
  RiskLevel risk = RiskLevel.low;
  RecordVitalSignCommand? last;
  Future<List<VitalSign>> Function()? loading;
  Future<VitalSign> Function(RecordVitalSignCommand)? recording;

  @override
  Future<List<VitalSign>> getAll() async {
    if (failure != null) throw failure!;
    return loading == null ? records : await loading!();
  }

  @override
  Future<List<VitalSign>> getByPatientId(String id) async =>
      records.where((s) => s.patientId == id).toList();

  @override
  Future<VitalSign> record(RecordVitalSignCommand c) async {
    writes++;
    last = c;
    if (failure != null) throw failure!;

    return recording == null
        ? vital(id: writes.toString(), risk: risk, command: c)
        : await recording!(c);
  }
}

Future<void> host(
  WidgetTester tester,
  FakeVitalApi api, {
  User actor = nurse,
  bool list = false,
}) async {
  final patientApi = FakePatientApi()
    ..patients = [patientFrom(patientCommand())];

  final container = ProviderContainer(
    overrides: [
      patientApiProvider.overrideWithValue(patientApi),
      patientPermissionsProvider.overrideWithValue(
        PatientPermissions(actor.roles),
      ),
      vitalSignUserProvider.overrideWithValue(actor),
      vitalSignNotifierProvider.overrideWith(
        (ref) => VitalSignNotifier(
          api,
          () => actor,
          patientApi.getById,
          VitalSignEffects(
            audit: (_, _) async {},
            createAlert: (_, _) async {},
          ),
        ),
      ),
    ],
  );

  addTearDown(container.dispose);
  await container.read(patientNotifierProvider.notifier).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: list
            ? const VitalSignListView()
            : Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: FilledButton(
                      onPressed: () => showVitalSignFormSheet(context),
                      child: const Text('Abrir formulario'),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  if (!list) {
    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> fill(
  WidgetTester tester, {
  String systolic = '120',
  String diastolic = '80',
}) async {
  await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Hab.').last);
  await tester.pumpAndSettle();

  for (final entry in {
    'vital-heart': '78',
    'vital-respiratory': '18',
    'vital-systolic': systolic,
    'vital-diastolic': diastolic,
    'vital-oxygen': '98',
    'vital-temperature': '36,5',
  }.entries) {
    final field = find.byKey(ValueKey(entry.key));
    await tester.ensureVisible(field);
    await tester.enterText(field, entry.value);
    await tester.pump();
  }
}

void main() {
  group('Reglas', () {
    test('intervalos incluyen extremos y rechazan valores fuera', () {
      for (final (label, min, max) in [
        ('FC', 20, 250),
        ('FR', 5, 80),
        ('Sistólica', 50, 260),
        ('Diastólica', 30, 180),
        ('SpO₂', 0, 100),
      ]) {
        expect(VitalSignRules.number('$min', label, min, max), isNull);
        expect(VitalSignRules.number('$max', label, min, max), isNull);
        expect(VitalSignRules.number('${min - 1}', label, min, max), isNotNull);
        expect(VitalSignRules.number('${max + 1}', label, min, max), isNotNull);
      }
    });

    test('enteros rechazan fracciones y números no finitos', () {
      for (final value in [
        '',
        ' ',
        '78.5',
        '78,5',
        'NaN',
        'Infinity',
        '1e2',
        '0x50',
      ]) {
        expect(VitalSignRules.number(value, 'FC', 20, 250), isNotNull);
      }
    });

    test('temperatura acepta coma/punto y límites', () {
      for (final value in ['30', '45', '36.5', '36,5']) {
        expect(
          VitalSignRules.number(value, 'Temperatura', 30, 45, integer: false),
          isNull,
        );
      }
      for (final value in ['29.9', '45.1', 'NaN', 'Infinity', '36,5,2']) {
        expect(
          VitalSignRules.number(value, 'Temperatura', 30, 45, integer: false),
          isNotNull,
        );
      }
    });

    test('sistólica debe superar diastólica', () {
      expect(VitalSignRules.pressure(120, 80), isNull);
      expect(VitalSignRules.pressure(80, 80), isNotNull);
      expect(VitalSignRules.pressure(80, 100), isNotNull);
      expect(
        () => VitalSignRules.validate(vitalCommand(systolic: 80), nurseId: '2'),
        throwsFormatException,
      );
    });

    test('comandos directos también rechazan valores inválidos', () {
      for (final value in [double.nan, double.infinity, 78.5]) {
        expect(
          () =>
              VitalSignRules.validate(vitalCommand(heart: value), nurseId: '2'),
          throwsFormatException,
        );
      }
      expect(
        () => VitalSignRules.validate(
          vitalCommand(temperature: double.nan),
          nurseId: '2',
        ),
        throwsFormatException,
      );
    });

    test('IDs positivos y nurseId del contexto autenticado', () {
      for (final value in [
        '',
        '0',
        '-1',
        '1.2',
        'null',
        '999999999999999999999',
      ]) {
        expect(VitalSignRules.id(value), isNotNull);
      }

      final c = VitalSignRules.validate(
        vitalCommand(nurseId: '999'),
        nurseId: '2',
      );
      expect(c.toJson()['nurseId'], 2);
      expect(c.toJson()['patientId'], 1);
      expect(c.toJson()['heartRate'], isA<int>());
      expect(c.toJson(), isNot(contains('recordedAt')));
    });

    test('formulario normaliza temperatura y claves del contrato', () {
      final c = VitalSignRules.fromForm(
        patientId: '1',
        nurseId: '2',
        heartRate: '78',
        respiratoryRate: '18',
        systolic: '120',
        diastolic: '80',
        oxygen: '98',
        temperature: '36,5',
      );
      expect(c.temperature, 36.5);
      expect(
        c.toJson().keys,
        containsAll([
          'patientId',
          'nurseId',
          'heartRate',
          'respiratoryRate',
          'systolicPressure',
          'diastolicPressure',
          'oxygenSaturation',
          'temperature',
        ]),
      );
    });

    test('solo Nurse/Admin registran', () {
      expect(VitalSignRules.canRecord([kRoleNurse]), isTrue);
      expect(VitalSignRules.canRecord([kRoleAdmin]), isTrue);
      expect(VitalSignRules.canRecord([kRoleDoctor]), isFalse);
      expect(VitalSignRules.canRecord(['UNKNOWN']), isFalse);
    });

    test('descripción de alerta cumple límite 255', () {
      final description = VitalSignRules.alertDescription(
        vital(
          risk: RiskLevel.critical,
          command: vitalCommand(
            heart: 250,
            respiratory: 80,
            systolic: 260,
            diastolic: 180,
            oxygen: 100,
            temperature: 45,
          ),
        ),
      );
      expect(description.length, lessThanOrEqualTo(255));
      expect(description, contains('Signos vitales críticos'));
      expect(description, contains('SpO₂'));
    });
  });

  group('Estado y permisos', () {
    late FakeVitalApi api;
    late User? actor;
    late ProviderContainer container;
    late VitalSignNotifier notifier;
    late Future<Patient> Function(String) patient;
    late int audits, alerts;
    Object? alertFailure;

    setUp(() {
      api = FakeVitalApi();
      actor = nurse;
      audits = 0;
      alerts = 0;
      alertFailure = null;
      patient = (id) async => patientFrom(patientCommand(), id: id);

      final effects = VitalSignEffects(
        audit: (_, _) async {
          audits++;
        },
        createAlert: (_, _) async {
          alerts++;
          if (alertFailure != null) throw alertFailure!;
        },
      );

      container = ProviderContainer(
        overrides: [
          vitalSignNotifierProvider.overrideWith(
            (ref) => VitalSignNotifier(
              api,
              () => actor,
              (id) => patient(id),
              effects,
            ),
          ),
        ],
      );
      notifier = container.read(vitalSignNotifierProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('validación y permiso bloquean HTTP', () async {
      await expectLater(
        notifier.record(vitalCommand(heart: double.nan)),
        throwsFormatException,
      );
      actor = const User(id: '2', username: 'doctor', roles: [kRoleDoctor]);
      await expectLater(notifier.record(vitalCommand()), throwsFormatException);
      expect(api.writes, 0);
      expect(audits, 0);
      expect(alerts, 0);
    });

    test('envía nurseId del usuario autenticado', () async {
      await notifier.record(vitalCommand(nurseId: '999'));
      expect(api.last!.nurseId, '2');
      expect(api.last!.toJson()['nurseId'], 2);
    });

    test('paciente inexistente bloquea guardado', () async {
      patient = (_) async =>
          throw const FormatException('Paciente no disponible');
      await expectLater(notifier.record(vitalCommand()), throwsFormatException);
      expect(api.writes, 0);
      expect(container.read(vitalSignNotifierProvider).saving, isFalse);
    });

    test('cambio de sesión durante consulta bloquea POST', () async {
      patient = (id) async {
        actor = null;
        return patientFrom(patientCommand(), id: id);
      };
      await expectLater(notifier.record(vitalCommand()), throwsFormatException);
      expect(api.writes, 0);
    });

    test('doble envío produce un solo POST', () async {
      final pending = Completer<VitalSign>();
      api.recording = (_) => pending.future;
      final first = notifier.record(vitalCommand());
      await Future<void>.delayed(Duration.zero);

      await expectLater(notifier.record(vitalCommand()), throwsFormatException);
      expect(api.writes, 1);

      pending.complete(vital());
      await first;
      expect(container.read(vitalSignNotifierProvider).saving, isFalse);
      expect(audits, 1);
    });

    test('fallo de POST conserva historial y no ejecuta efectos', () async {
      api.records = [vital(id: '50')];
      await notifier.load();
      api.failure = const FormatException('Servidor fuera de línea');

      await expectLater(notifier.record(vitalCommand()), throwsFormatException);
      expect(container.read(vitalSignNotifierProvider).records.single.id, '50');
      expect(container.read(vitalSignNotifierProvider).saving, isFalse);
      expect(audits, 0);
      expect(alerts, 0);
    });

    test('fallo de alerta conserva medición y no repite POST', () async {
      api.risk = RiskLevel.high;
      alertFailure = StateError('Alertas sin conexión');

      final saved = await notifier.record(vitalCommand());
      expect(saved.id, '1');
      expect(api.writes, 1);
      expect(alerts, 1);
      expect(audits, 1);
      expect(container.read(vitalSignNotifierProvider).records, hasLength(1));
      expect(
        container.read(vitalSignNotifierProvider).warning,
        contains('se guardaron'),
      );

      notifier.clearWarning();
      expect(container.read(vitalSignNotifierProvider).warning, isNull);
    });

    test('riesgo bajo audita sin alerta', () async {
      await notifier.record(vitalCommand());
      expect(audits, 1);
      expect(alerts, 0);
    });

    test('carga anterior no borra medición guardada', () async {
      final pending = Completer<List<VitalSign>>();
      api.loading = () => pending.future;

      final load = notifier.load();
      await notifier.record(vitalCommand());
      pending.complete([]);
      await load;

      expect(container.read(vitalSignNotifierProvider).records, hasLength(1));
      expect(container.read(vitalSignNotifierProvider).loading, isFalse);
    });

    test('ordena historial y conserva datos tras error', () async {
      api.records = [
        vital(id: '1', at: DateTime(2025)),
        vital(id: '2', at: DateTime(2026)),
      ];
      await notifier.load();
      expect(
        container.read(vitalSignNotifierProvider).records.map((s) => s.id),
        ['2', '1'],
      );

      api.failure = const FormatException('Sin conexión');
      await notifier.load();
      expect(container.read(vitalSignNotifierProvider).records, hasLength(2));
      expect(container.read(vitalSignNotifierProvider).error, 'Sin conexión');

      api.failure = null;
      await notifier.load();
      expect(container.read(vitalSignNotifierProvider).error, isNull);
    });
  });

  group('Alertas y auditoría', () {
    test('alerta solo para alto/crítico y auditoría para todos', () async {
      var audits = 0, alerts = 0;
      final effects = VitalSignEffects(
        audit: (_, _) async {
          audits++;
        },
        createAlert: (_, _) async {
          alerts++;
        },
      );

      for (final risk in RiskLevel.values) {
        expect(await effects.run(vital(risk: risk), nurse), isNull);
      }

      expect(audits, 5);
      expect(alerts, 2);
    });

    test('fallo de auditoría no impide alerta', () async {
      var alerts = 0;
      final effects = VitalSignEffects(
        audit: (_, _) async => throw StateError('Audit unavailable'),
        createAlert: (_, _) async {
          alerts++;
        },
      );

      expect(
        await effects.run(vital(risk: RiskLevel.critical), nurse),
        contains('auditoría'),
      );
      expect(alerts, 1);
    });

    test('fallos posteriores se informan sin error de guardado', () async {
      final effects = VitalSignEffects(
        audit: (_, _) async => throw StateError('audit'),
        createAlert: (_, _) async => throw StateError('alert'),
      );
      final warning = await effects.run(vital(risk: RiskLevel.high), nurse);

      expect(warning, contains('auditoría'));
      expect(warning, contains('alerta'));
    });
  });

  group('Contrato HTTP', () {
    test('POST incluye nurseId real y cinco enteros', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      addTearDown(dio.close);

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/vital-sign-records');
            final data = options.data as Map<String, dynamic>;
            expect(data['nurseId'], 2);
            expect(data['patientId'], 1);

            for (final key in [
              'heartRate',
              'respiratoryRate',
              'systolicPressure',
              'diastolicPressure',
              'oxygenSaturation',
            ]) {
              expect(data[key], isA<int>());
            }

            expect(data['temperature'], 36.5);
            expect(data, isNot(contains('recordedAt')));

            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'id': 1,
                  'patientId': 1,
                  'nurseId': 2,
                  'heartRate': 78,
                  'respiratoryRate': 18,
                  'systolic': 120,
                  'diastolic': 80,
                  'oxygenSaturation': 98,
                  'temperature': 36.5,
                  'riskLevel': 'UNASSESSED',
                  'recordedAt': '2026-10-04T01:00:00Z',
                },
              ),
            );
          },
        ),
      );

      final sign = await VitalSignApi(dio)
          .record(VitalSignRules.validate(vitalCommand(), nurseId: nurse.id));
      expect(sign.id, '1');
      expect(sign.nurseId, nurse.id);
    });
  });

  group('Pantallas', () {
    testWidgets('rechaza paciente vacío y presión igual sin POST', (
      tester,
    ) async {
      final api = FakeVitalApi();
      await host(tester, api);

      await tapVisible(tester, find.byKey(const ValueKey('vital-save')));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona un paciente disponible.'), findsOneWidget);
      expect(api.writes, 0);

      await fill(tester, systolic: '80', diastolic: '80');
      await tapVisible(tester, find.byKey(const ValueKey('vital-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('La presión sistólica debe ser mayor que la diastólica.'),
        findsOneWidget,
      );
      expect(api.writes, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('registro usa sesión, normaliza coma y cierra', (tester) async {
      final api = FakeVitalApi();
      await host(tester, api);
      await fill(tester);

      await tapVisible(tester, find.byKey(const ValueKey('vital-save')));
      await tester.pumpAndSettle();

      expect(api.writes, 1);
      expect(api.last!.nurseId, '2');
      expect(api.last!.temperature, 36.5);
      expect(find.byKey(const ValueKey('vital-save')), findsNothing);
      expect(find.text('Signos vitales guardados.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error conserva formulario y valores', (tester) async {
      final api = FakeVitalApi()
        ..failure = const FormatException('Servidor fuera de línea');
      await host(tester, api);
      await fill(tester);

      await tapVisible(tester, find.byKey(const ValueKey('vital-save')));
      await tester.pumpAndSettle();

      expect(find.text('Servidor fuera de línea'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('vital-temperature')),
            )
            .controller!
            .text,
        '36,5',
      );

      api.failure = null;
      await tapVisible(tester, find.byKey(const ValueKey('vital-save')));
      await tester.pumpAndSettle();

      expect(api.writes, 2);
      expect(find.byKey(const ValueKey('vital-save')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Doctor consulta sin botón Registrar', (tester) async {
      final api = FakeVitalApi()..records = [vital()];
      await host(
        tester,
        api,
        list: true,
        actor: const User(id: '3', username: 'doctor', roles: [kRoleDoctor]),
      );

      expect(find.text('Registrar'), findsNothing);
      expect(find.textContaining('Temperatura:'), findsOneWidget);
      expect(find.textContaining('Ana'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
