import '../../../shared/widgets/list_page_body.dart';
import '../../../core/localization/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_title.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/clinical_card.dart';
import '../../patient/application/patient_notifier.dart';
import '../application/sbar_notifier.dart';
import '../domain/sbar_rules.dart';
import '../domain/sbar_transfer.dart';
import 'sbar_form_dialog.dart';
import 'sbar_detail_dialog.dart';

class SbarListView extends ConsumerStatefulWidget {
  const SbarListView({super.key});
  @override
  ConsumerState<SbarListView> createState() => _SbarListViewState();
}

class _SbarListViewState extends ConsumerState<SbarListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(sbarNotifierProvider.notifier).load();
      if (SbarRules.canRead(ref.read(sbarUserProvider)?.roles ?? [])) {
        ref.read(patientNotifierProvider.notifier).load();
      }
    });
  }

  Future<void> _acknowledge(SbarTransfer transfer) async {
    try {
      await ref.read(sbarNotifierProvider.notifier).acknowledge(transfer.id);
      if (mounted) {
        final warning = ref.read(sbarNotifierProvider).warning;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(warning ?? 'Recepción del traspaso confirmada.'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr(describeSbarError(e)))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sbarNotifierProvider);
    final allowed = ref.watch(sbarCanManageProvider);
    final patients = ref.watch(patientNotifierProvider).patients;
    final users = ref.watch(sbarUsersProvider).valueOrNull ?? [];
    return Scaffold(
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              onPressed: state.saving ? null : () => showSbarForm(context),
              icon: Icon(Icons.add),
              label: Text(context.tr('Nuevo traspaso')),
            )
          : null,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListPageBody(
          header: [
            PageTitle('Traspasos SBAR'),
            if (state.loading || state.saving) LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.error!))),
                    TextButton(
                      onPressed: state.loading || state.saving
                          ? null
                          : () =>
                                ref.read(sbarNotifierProvider.notifier).load(),
                      child: Text(context.tr('Reintentar')),
                    ),
                  ],
                ),
              ),
            if (state.warning != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: Text(context.tr(state.warning!))),
                    IconButton(
                      tooltip: context.tr('Ocultar aviso'),
                      icon: Icon(Icons.close),
                      onPressed: () => ref
                          .read(sbarNotifierProvider.notifier)
                          .clearWarning(),
                    ),
                  ],
                ),
              ),
          ],
          child: RefreshIndicator(
            onRefresh: () => ref.read(sbarNotifierProvider.notifier).load(),
            child: ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: state.transfers.isEmpty ? 1 : state.transfers.length,
              itemBuilder: (context, index) {
                if (state.transfers.isEmpty) {
                  return state.loading || state.error != null
                      ? SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            context.tr(
                              'No hay traspasos SBAR registrados todavía.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                }
                final t = state.transfers[index];
                var patientName = context.tr('Paciente #${t.patientId}');
                for (final p in patients) {
                  if (p.id == t.patientId) patientName = p.fullName;
                }
                var receiver = t.targetNurseId == null
                    ? context.tr('Sin receptor asignado')
                    : context.tr('Enfermero #${t.targetNurseId}');
                for (final u in users) {
                  if (u.id == t.targetNurseId) receiver = u.username;
                }
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: ClinicalCard(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => SbarDetailDialog(transferId: t.id),
                    ),
                    children: [
                      Text(
                        t.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '$patientName\n${t.registeredBy ?? context.tr('Sin información')} → $receiver\n'
                        '${t.transferredAt == null ? context.tr('Fecha no disponible') : DateFormat('dd/MM/yyyy HH:mm').format(t.transferredAt!.toLocal())}\n'
                        'S: ${t.situation}',
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(
                            label: t.statusLabel,
                            palette: ClinicalColors.sbarStatus(t.status),
                          ),
                          if (allowed &&
                              t.canAcknowledge &&
                              !state.confirmedAcknowledgements.contains(t.id))
                            IconButton(
                              key: ValueKey('sbar-ack-${t.id}'),
                              tooltip: context.tr('Confirmar recepción'),
                              icon: Icon(Icons.check_circle_outline),
                              onPressed: state.saving
                                  ? null
                                  : () => _acknowledge(t),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
