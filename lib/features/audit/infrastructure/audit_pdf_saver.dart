import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audit_rules.dart';

typedef AuditPdfSaver = Future<bool> Function(Uint8List bytes);

class AuditPdfFileSaver {
  const AuditPdfFileSaver();
  static const channel = MethodChannel('nursepulse/audit_pdf');

  Future<bool> save(Uint8List bytes) async {
    if (!AuditRules.isPdf(bytes)) {
      throw const FormatException(
        'El documento PDF está incompleto o es inválido.',
      );
    }
    try {
      final saved = await channel.invokeMethod<bool>('save', {
        'bytes': bytes,
        'name': 'auditoria-nursepulse.pdf',
      });
      if (saved == null) {
        throw const FormatException(
          'No se pudo confirmar el guardado del PDF.',
        );
      }
      return saved;
    } on MissingPluginException {
      throw const FormatException(
        'El guardado de PDF no está disponible en esta plataforma.',
      );
    } on PlatformException {
      throw const FormatException(
        'No se pudo guardar el PDF. Puedes volver a elegir un destino.',
      );
    }
  }
}

final auditPdfSaverProvider = Provider<AuditPdfSaver>(
  (ref) => const AuditPdfFileSaver().save,
);
