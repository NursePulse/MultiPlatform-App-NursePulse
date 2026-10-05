import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../features/vital_sign/domain/vital_sign.dart';

/// The same recorded measurements in lists and patient history, without
/// truncation or fixed heights. Units remain attached to their values.
class VitalMetrics extends StatelessWidget {
  const VitalMetrics(this.record, {super.key});
  final VitalSign record;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 280 &&
              MediaQuery.textScalerOf(context).scale(15) < 22
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      final values = [
        (Icons.favorite_border, 'FC', context.tr('${record.heartRate} lpm')),
        (Icons.air, 'FR', context.tr('${record.respiratoryRate} rpm')),
        (
          Icons.monitor_heart_outlined,
          'TA',
          '${record.systolic}/${record.diastolic} mmHg',
        ),
        (Icons.water_drop_outlined, 'SpO₂', '${record.oxygenSaturation} %'),
        (Icons.thermostat_outlined, 'Temperatura', '${record.temperature} °C'),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final value in values)
            Container(
              width: width,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    value.$1,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(value.$2),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value.$3,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
