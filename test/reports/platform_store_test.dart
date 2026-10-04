import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/report/infrastructure/report_local_store.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final values = <String, String>{};
  final calls = <String>[];
  var failWrite = false;
  setUp(() {
    values.clear();
    calls.clear();
    failWrite = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          calls.add('${call.method} ${args['key']}');
          if (call.method == 'read') return values[args['key']];
          if (call.method == 'write') {
            if (failWrite) {
              throw PlatformException(code: 'SIMULATED_WRITE_FAILURE');
            }
            values[args['key'] as String] = args['value'] as String;
            return null;
          }
          throw StateError('Operación inesperada ${call.method}');
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('almacenamiento real configurado conserva reporte entre instancias mediante canal local', () async {
    final original = report();
    await ReportLocalStore().add(original);
    expect(values.keys, [ReportLocalStore.storageKey]);
    final loaded = (await ReportLocalStore().getAll()).single;
    expect(loaded.toJson(), original.toJson());
    expect(calls, [
      'read ${ReportLocalStore.storageKey}',
      'write ${ReportLocalStore.storageKey}',
      'read ${ReportLocalStore.storageKey}',
    ]);
  });
  test('JSON corrupto del canal local devuelve lista vacía', () async {
    values[ReportLocalStore.storageKey] = 'broken';
    expect(await ReportLocalStore().getAll(), isEmpty);
    expect(calls, ['read ${ReportLocalStore.storageKey}']);
  });
  test('error nativo de escritura no devuelve un guardado exitoso', () async {
    failWrite = true;
    await expectLater(
      ReportLocalStore().add(report()),
      throwsA(isA<PlatformException>()),
    );
    expect(values, isEmpty);
  });
}
