import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/sbar_transfer.dart';

/// Una escritura confirmada puede no tener detalle disponible todavía.
class SbarWriteReceipt {
  const SbarWriteReceipt({this.id, this.transfer, this.readError});
  final String? id;
  final SbarTransfer? transfer;
  final Object? readError;
}

class SbarApi {
  SbarApi(this._dio);
  final Dio _dio;

  Future<List<SbarTransfer>> getByPatientId(String patientId) async {
    final response = await _dio.get('/handovers/patients/$patientId');
    return (response.data as List)
        .map((e) => SbarTransfer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SbarTransfer> getById(String id) async {
    final response = await _dio.get('/handovers/$id');
    final transfer = SbarTransfer.fromJson(
      response.data as Map<String, dynamic>,
    );
    if (transfer.id != id) {
      throw const FormatException(
        'El detalle no corresponde al traspaso solicitado.',
      );
    }
    return transfer;
  }

  static String? _id(Object? value) {
    final text = value?.toString() ?? '';
    final number = int.tryParse(text);
    return RegExp(r'^[0-9]+$').hasMatch(text) && number != null && number > 0
        ? number.toString()
        : null;
  }

  /// El POST existente devuelve un ID. Una falla del GET posterior no revierte
  /// esa confirmación ni debe habilitar otro POST del mismo formulario.
  Future<SbarWriteReceipt> register(RegisterSbarCommand command) async {
    final response = await _dio.post('/handovers', data: command.toJson());
    final data = response.data;
    final id = _id(data is Map ? data['id'] : data);
    if (id == null) {
      return const SbarWriteReceipt(
        readError: FormatException(
          'El servidor confirmó la creación sin devolver un identificador válido.',
        ),
      );
    }
    try {
      final transfer = data is Map<String, dynamic>
          ? SbarTransfer.fromJson(data)
          : await getById(id);
      return SbarWriteReceipt(id: id, transfer: transfer);
    } catch (e) {
      return SbarWriteReceipt(id: id, readError: e);
    }
  }

  /// La identidad de quien recibe el turno se deriva del JWT en el servidor.
  Future<SbarWriteReceipt> acknowledge(
    String id, {
    String? additionalNotes,
  }) async {
    final response = await _dio.patch(
      '/handovers/$id/acknowledge',
      data: {'additionalNotes': ?additionalNotes},
    );
    try {
      final transfer = SbarTransfer.fromJson(
        response.data as Map<String, dynamic>,
      );
      if (transfer.id != id) {
        throw const FormatException(
          'La respuesta no corresponde al traspaso solicitado.',
        );
      }
      return SbarWriteReceipt(id: id, transfer: transfer);
    } catch (e) {
      return SbarWriteReceipt(id: id, readError: e);
    }
  }
}

final sbarApiProvider = Provider((ref) => SbarApi(ref.watch(dioProvider)));
