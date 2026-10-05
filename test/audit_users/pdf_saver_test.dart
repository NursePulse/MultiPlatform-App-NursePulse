import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurse_pulse_app/features/audit/infrastructure/audit_pdf_saver.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(
    () => messenger.setMockMethodCallHandler(AuditPdfFileSaver.channel, null),
  );
  tearDown(
    () => messenger.setMockMethodCallHandler(AuditPdfFileSaver.channel, null),
  );
  for (final success in [true, false]) {
    test('canal nativo confirma guardado=$success sin inventar ruta', () async {
      messenger.setMockMethodCallHandler(AuditPdfFileSaver.channel, (
        call,
      ) async {
        expect(call.method, 'save');
        expect((call.arguments as Map)['bytes'], pdf);
        expect((call.arguments as Map)['name'], 'auditoria-nursepulse.pdf');
        return success;
      });
      expect(await const AuditPdfFileSaver().save(pdf), success);
    });
  }
  test('PDF inválido no llega al canal nativo', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(AuditPdfFileSaver.channel, (_) async {
      calls++;
      return true;
    });
    await expectLater(
      const AuditPdfFileSaver().save(Uint8List.fromList('invalid'.codeUnits)),
      throwsFormatException,
    );
    expect(calls, 0);
  });
  test('respuesta nativa ausente no declara éxito', () async {
    messenger.setMockMethodCallHandler(
      AuditPdfFileSaver.channel,
      (_) async => null,
    );
    await expectLater(
      const AuditPdfFileSaver().save(pdf),
      throwsFormatException,
    );
  });
  test('error de escritura nativa permite informar recuperación', () async {
    messenger.setMockMethodCallHandler(
      AuditPdfFileSaver.channel,
      (_) async => throw PlatformException(code: 'SAVE_FAILED'),
    );
    await expectLater(
      const AuditPdfFileSaver().save(pdf),
      throwsFormatException,
    );
  });
  test('plataforma sin canal informa indisponibilidad', () async {
    await expectLater(
      const AuditPdfFileSaver().save(pdf),
      throwsFormatException,
    );
  });
}
