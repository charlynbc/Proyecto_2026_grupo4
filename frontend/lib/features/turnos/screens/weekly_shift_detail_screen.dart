import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../../core/utils/ui_date.dart';
import '../models/shift_number.dart';
import '../models/weekday_names.dart';
import '../models/weekly_shift.dart';
import '../providers/weekly_shift_provider.dart';
import '../repositories/shift_repository.dart';
import 'shift_routes.dart';

/// Detalle de una configuración semanal (RF-17): el patrón con su vigencia, los
/// números con su horario y cuántas fechas generó.
class WeeklyShiftDetailScreen extends ConsumerWidget {
  const WeeklyShiftDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeklyShift = ref.watch(weeklyShiftProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Turno semanal')),
      body: CenteredContent(
        maxWidth: 700,
        child: weeklyShift.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _LoadError(
            notFound: error is ShiftNotFoundException,
            onRetry: () => ref.invalidate(weeklyShiftProvider(id)),
          ),
          data: (data) => _Detail(data),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go(kShiftsPath),
      icon: const Icon(Icons.arrow_back),
      label: const Text('Volver al listado'),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.notFound, required this.onRetry});

  /// El turno no existe: reintentar no sirve, solo volver.
  final bool notFound;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notFound
              ? 'Ese turno semanal no existe o ya no está disponible. Volvé '
                    'al listado y buscalo de nuevo.'
              : 'No pudimos cargar el turno semanal. Intentá de nuevo.',
          style: TextStyle(color: colorScheme.error),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (!notFound)
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            const _BackButton(),
          ],
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.weeklyShift);

  final WeeklyShift weeklyShift;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = weeklyShift.shiftCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field('Médico', weeklyShift.doctor.fullName),
        _Field('Especialidad', weeklyShift.specialty.name),
        _Field(
          'Consultorio',
          '${weeklyShift.clinic.name} (${weeklyShift.clinic.location})',
        ),
        _Field('Día', weekdayLabel(weeklyShift.weekday)),
        _Field(
          'Vigencia',
          'Del ${formatUiDate(weeklyShift.startDate)} al '
              '${formatUiDate(weeklyShift.endDate)}',
        ),
        _Field('Fechas generadas', '$count ${count == 1 ? 'fecha' : 'fechas'}'),
        const SizedBox(height: 8),
        Text('Números', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final number in weeklyShift.numbers)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Número ${number.number}: '
              '${ShiftNumber.formatTime(number.startMinutes)} – '
              '${ShiftNumber.formatTime(number.endMinutes)} '
              '(${number.duration} min)',
            ),
          ),
        const SizedBox(height: 16),
        const _BackButton(),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          Text(value, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
