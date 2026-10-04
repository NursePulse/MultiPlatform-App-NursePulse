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
      title: const Text('Detalle del traspaso SBAR'),
      content: SizedBox(
        width: 420,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(describeSbarError(error)),
              TextButton(
                onPressed: () => ref.invalidate(sbarDetailProvider(transferId)),
                child: const Text('Reintentar detalle'),
              ),
            ],
          ),
          data: (t) {
            var patientName = 'Paciente #${t.patientId}';
            for (final p in patients) {
              if (p.id == t.patientId) patientName = p.fullName;
            }
            var receiver = t.targetNurseId == null
                ? 'Sin receptor asignado'
                : 'Enfermero #${t.targetNurseId}';
            var incoming = t.incomingNurseId == null
                ? null
                : 'Enfermero #${t.incomingNurseId}';
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
                    'Registrado por: ${t.registeredBy ?? 'Sin información'}',
                  ),
                  Text('Para: $receiver'),
                  Text('Estado: ${t.statusLabel}'),
                  if (t.transferredAt != null)
                    Text(
                      'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(t.transferredAt!.toLocal())}',
                    ),
                  if (incoming != null) Text('Recibido por: $incoming'),
                  const SizedBox(height: 16),
                  for (final section in [
                    ('Situación', t.situation),
                    ('Antecedentes', t.background),
                    ('Evaluación', t.assessment),
                    ('Recomendación', t.recommendation),
                    if (t.additionalNotes?.isNotEmpty == true)
                      ('Notas de atención', t.additionalNotes!),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.$1,
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
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
