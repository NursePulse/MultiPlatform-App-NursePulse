import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../features/audit/domain/audit_log.dart';
import 'clinical_card.dart';
import 'page_action.dart';

class AuditEntryCard extends StatelessWidget {
  const AuditEntryCard(this.entry, {super.key});
  final AuditLog entry;

  @override
  Widget build(BuildContext context) => ClinicalCard(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(Icons.history)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(entry.actionLabel),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(entry.code, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(entry.description),
      const SizedBox(height: 12),
      const Divider(),
      EntityReference(context.tr(entry.entityLabel), entry.entityId),
      MetadataLine(
        Icons.person_outline,
        context.tr('Por ${entry.performedBy}'),
      ),
      MetadataLine(
        Icons.schedule,
        DateFormat('dd/MM/yyyy HH:mm').format(entry.performedAt.toLocal()),
      ),
    ],
  );
}

/// Abbreviation is presentation only. Full IDs remain selectable and are
/// never shortened in models, filtering, requests or PDF exports.
class EntityReference extends StatelessWidget {
  const EntityReference(this.label, this.id, {super.key});
  final String label, id;

  @override
  Widget build(BuildContext context) {
    final short = id.length > 18
        ? '${id.substring(0, 8)}…${id.substring(id.length - 6)}'
        : id;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Referencia')),
            scrollable: true,
            content: SelectableText('$label #$id'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Cerrar')),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.tag, size: 18),
        label: Text(
          '$label #$short',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
