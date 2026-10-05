import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../patient/application/patient_notifier.dart';
import '../application/sbar_notifier.dart';

class SbarDetailDialog extends ConsumerWidget {
  const SbarDetailDialog({super.key, required this.transferId});
  final String transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sbarDetailProvider(transferId));
    final users = ref.watch(sbarUsersProvider).valueOrNull ?? [];
    final patients = ref.watch(patientNotifierProvider).patients;
    return AlertDialog(
      title: Text(context.tr('Detalle del traspaso SBAR')),
      content: SizedBox(
        width: 420,
        child: detail.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr(describeSbarError(error))),
              TextButton(
                onPressed: () => ref.invalidate(sbarDetailProvider(transferId)),
                child: Text(context.tr('Reintentar detalle')),
              ),
            ],
          ),
          data: (t) {
            var patientName = context.tr('Paciente #${t.patientId}');
            for (final p in patients) {
              if (p.id == t.patientId) patientName = p.fullName;
            }
            var receiver = t.targetNurseId == null
                ? context.tr('Sin receptor asignado')
                : context.tr('Enfermero #${t.targetNurseId}');
            var incoming = t.incomingNurseId == null
                ? null
                : context.tr('Enfermero #${t.incomingNurseId}');
            for (final u in users) {
              if (u.id == t.targetNurseId) receiver = u.username;
              if (u.id == t.incomingNurseId) incoming = u.username;
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(patientName),
                  Text(
                    context.tr(
                      'Registrado por: ${t.registeredBy ?? context.tr('Sin información')}',
                    ),
                  ),
                  Text(context.tr('Para: $receiver')),
                  Text(context.tr('Estado: ${context.tr(t.statusLabel)}')),
                  if (t.transferredAt != null)
                    Text(
                      context.tr(
                        'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(t.transferredAt!.toLocal())}',
                      ),
                    ),
                  if (incoming != null)
                    Text(context.tr('Recibido por: $incoming')),
                  SizedBox(height: 16),
                  for (final section in [
                    ('Situación', t.situation),
                    ('Antecedentes', t.background),
                    ('Evaluación', t.assessment),
                    ('Recomendación', t.recommendation),
                    if (t.additionalNotes?.isNotEmpty == true)
                      ('Notas de atención', t.additionalNotes!),
                  ])
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(section.$1),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(section.$2.isEmpty ? '—' : section.$2),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cerrar')),
        ),
      ],
    );
  }
}
