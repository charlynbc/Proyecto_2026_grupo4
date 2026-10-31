import 'package:flutter/material.dart';

import '../models/appointment_statistics.dart';

/// Las dos tarjetas de arriba: el total del período y la tasa de cancelación
/// por el socio. Los valores son los que manda el servidor: acá no se suma ni
/// se calcula ningún porcentaje.
class AppointmentSummaryCards extends StatelessWidget {
  const AppointmentSummaryCards({super.key, required this.statistics});

  final AppointmentStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final total = _SummaryCard(
      title: 'Consultas del período (por fecha de consulta)',
      valueKey: const Key('stats-total-value'),
      value: '${statistics.total}',
    );
    final rate = _SummaryCard(
      title: 'Tasa de cancelación por el socio',
      valueKey: const Key('stats-rate-value'),
      value: statistics.percentageText,
      noteKey: const Key('stats-rate-subtitle'),
      note: '${statistics.cancelledBySocio} de ${statistics.total} consultas',
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 480
          // La pantalla hace scroll vertical: sin `IntrinsicHeight` el alto
          // sería infinito y `stretch` no podría igualar las dos tarjetas.
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: total),
                  const SizedBox(width: 12),
                  Expanded(child: rate),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [total, const SizedBox(height: 8), rate],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.valueKey,
    required this.value,
    this.noteKey,
    this.note,
  });

  final String title;
  final Key valueKey;
  final String value;
  final Key? noteKey;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(value, key: valueKey, style: theme.textTheme.headlineMedium),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(
                note!,
                key: noteKey,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
