import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/iam/domain/user.dart';
import 'package:nurse_pulse_app/features/patient/application/patient_notifier.dart';
import 'package:nurse_pulse_app/features/patient/domain/patient.dart';

import 'fixtures.dart';
import 'fake_patient_api.dart';

void main() {
  late FakePatientApi api;
  late ProviderContainer container;
  late PatientNotifier notifier;
  late List<String> roles;

  setUp(() {
    api = FakePatientApi();
    roles = [kRoleNurse];

    container = ProviderContainer(
      overrides: [
        patientNotifierProvider.overrideWith(
          (ref) => PatientNotifier(api, () => roles),
        ),
      ],
    );

    notifier = container.read(patientNotifierProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('comando inválido no llega a la API y libera saving', () async {
    await expectLater(
      notifier.create(patientCommand(document: 'abc')),
      throwsFormatException,
    );

    expect(api.writes, 0);
    expect(container.read(patientNotifierProvider).saving, isFalse);
  });

  test(
    'duplicado bloquea creación pero permite editar el propio documento',
    () async {
      api.patients = [patientFrom(patientCommand())];
      await notifier.load();

      await expectLater(
        notifier.create(patientCommand()),
        throwsFormatException,
      );

      expect(api.writes, 0);

      await notifier.update('1', patientCommand());

      expect(api.writes, 1);
      expect(container.read(patientNotifierProvider).patients, hasLength(1));
    },
  );

  test(
    'doctor no crea y enfermería no elimina incluso llamando al notifier',
    () async {
      roles = [kRoleDoctor];

      await expectLater(
        notifier.create(patientCommand()),
        throwsFormatException,
      );

      roles = [kRoleNurse];

      await expectLater(notifier.delete('1'), throwsFormatException);
      expect(api.writes, 0);
    },
  );

  test('doble envío hace una sola escritura', () async {
    final pending = Completer<Patient>();
    api.creating = (_) => pending.future;

    final first = notifier.create(patientCommand());

    expect(container.read(patientNotifierProvider).saving, isTrue);
    await expectLater(notifier.create(patientCommand()), throwsFormatException);
    expect(api.writes, 1);

    pending.complete(patientFrom(patientCommand()));
    await first;

    expect(container.read(patientNotifierProvider).saving, isFalse);
  });

  test(
    'fallo de actualización conserva la lista y permite reintentar',
    () async {
      api.patients = [patientFrom(patientCommand())];
      await notifier.load();

      api.failure = const FormatException('Servidor no disponible');

      await expectLater(
        notifier.update('1', patientCommand(first: 'Rosa')),
        throwsFormatException,
      );

      expect(
        container
            .read(patientNotifierProvider)
            .patients
            .single
            .firstName
            .trim(),
        'Ana',
      );
      expect(container.read(patientNotifierProvider).saving, isFalse);

      api.failure = null;
      await notifier.update('1', patientCommand(first: 'Rosa'));

      expect(
        container.read(patientNotifierProvider).patients.single.firstName,
        'Rosa',
      );
    },
  );

  test('alta preserva todos los datos, incluso perfiles antiguos', () async {
    final original = patientCommand(gender: 'Femenino');

    api.patients = [patientFrom(original)];
    await notifier.load();
    await notifier.discharge('1');

    final expected = original.toJson()..['status'] = 'DISCHARGED';

    expect(api.lastCommand!.toJson(), expected);
  });

  test('una carga antigua no borra la creación que terminó después', () async {
    final pending = Completer<List<Patient>>();
    api.loading = () => pending.future;

    final load = notifier.load();
    await notifier.create(patientCommand());

    pending.complete([]);
    await load;

    expect(container.read(patientNotifierProvider).patients, hasLength(1));
    expect(container.read(patientNotifierProvider).loading, isFalse);
  });

  test('error de refresh conserva pacientes y retry limpia el error', () async {
    api.patients = [patientFrom(patientCommand())];
    await notifier.load();

    api.failure = const FormatException('Sin conexión');
    await notifier.load();

    expect(container.read(patientNotifierProvider).patients, hasLength(1));
    expect(container.read(patientNotifierProvider).error, 'Sin conexión');

    api.failure = null;
    await notifier.load();

    expect(container.read(patientNotifierProvider).error, isNull);
  });

  test('rechazo del servidor al eliminar no quita el paciente local', () async {
    roles = [kRoleAdmin];
    api.patients = [patientFrom(patientCommand())];

    await notifier.load();
    api.failure = const FormatException('Paciente con registros asociados');

    await expectLater(notifier.delete('1'), throwsFormatException);
    expect(container.read(patientNotifierProvider).patients, hasLength(1));

    api.failure = null;
    await notifier.delete('1');

    expect(container.read(patientNotifierProvider).patients, isEmpty);
  });
}
