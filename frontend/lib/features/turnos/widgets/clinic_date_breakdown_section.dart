import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic_date_breakdown.dart';
import '../providers/clinic_date_breakdown_provider.dart';

/// El consultorio de cada fecha de hoy en adelante de un turno semanal cuyo
/// consultorio varía, y cuántas fechas ya pasaron. Si no se puede cargar, lo
/// dice acá: el resto del detalle no depende de este bloque.
class ClinicDateBreakdownSection extends ConsumerWidget {
  const ClinicDateBreakdownSection({super.key, required this.weeklyShiftId});

  final int weeklyShiftId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(clinicDateBreakdownProvider(weeklyShiftId));
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consultorio de cada fecha (de hoy en adelante)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        breakdown.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              key: Key('clinic-breakdown-loading'),
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No pudimos cargar el desglose de consultorios.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(clinicDateBreakdownProvider(weeklyShiftId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (data) => _Lines(data),
        ),
      ],
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines(this.breakdown);

  final ClinicDateBreakdown breakdown;

  static String _count(int count, String singular, String plural) =>
      '$count ${count == 1 ? singular : plural}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in breakdown.upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${item.clinic.name} (${item.clinic.location}): '
              '${_count(item.dates, 'fecha', 'fechas')}'
              '${item.suspended > 0 ? ', ${_count(item.suspended, 'suspendida', 'suspendidas')}' : ''}',
            ),
          ),
        Text('Fechas pasadas: ${breakdown.past}, no cuentan para el aviso'),
      ],
    );
  }
}
