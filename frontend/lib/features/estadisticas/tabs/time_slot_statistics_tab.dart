import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../time_slots/models/time_slot_statistics.dart';
import '../time_slots/providers/time_slot_statistics_provider.dart';
import '../time_slots/repositories/time_slot_statistics_repository.dart';
import '../widgets/period_filter.dart';
import '../widgets/period_label.dart';

class TimeSlotStatisticsTab extends ConsumerStatefulWidget {
  const TimeSlotStatisticsTab({super.key});
  @override
  ConsumerState<TimeSlotStatisticsTab> createState() =>
      _TimeSlotStatisticsTabState();
}

class _TimeSlotStatisticsTabState extends ConsumerState<TimeSlotStatisticsTab> {
  final fromController = TextEditingController();
  final toController = TextEditingController();
  DateTime? from, to, requestedFrom, requestedTo;
  int? specialtyId;
  TimeSlotView view = TimeSlotView.consultations;
  TimeSlotStatistics? result;
  String? error, periodError;
  bool loading = true;
  int request = 0;
  @override
  void initState() {
    super.initState();
    fetch(null, null);
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  Future<void> fetch(DateTime? start, DateTime? end) async {
    requestedFrom = start;
    requestedTo = end;
    final id = ++request;
    final selectedSpecialty = specialtyId;
    final selectedView = view;
    if (!loading || error != null) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final repo = await ref.read(timeSlotStatisticsRepositoryProvider.future);
      final data = await repo.statistics(
        from: start,
        to: end,
        specialtyId: selectedSpecialty,
        view: selectedView,
      );
      if (!mounted || id != request) return;
      fromController.text = formatUiDate(data.from);
      toController.text = formatUiDate(data.to);
      setState(() {
        result = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted || id != request) return;
      setState(() {
        error = apiMessageOf(e);
        loading = false;
      });
    }
  }

  void consult() {
    if (from != null && to != null && from!.isAfter(to!)) {
      setState(
        () => periodError =
            'La fecha Desde no puede ser posterior a la fecha Hasta.',
      );
      return;
    }
    setState(() => periodError = null);
    fetch(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final specialties = ref.watch(specialtiesProvider);
    return CenteredContent(
      maxWidth: 720,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Vista'),
          Wrap(
            spacing: 8,
            children: [
              for (final option in TimeSlotView.values)
                ChoiceChip(
                  label: Text(
                    option == TimeSlotView.consultations
                        ? 'Consultas'
                        : 'Llegadas',
                  ),
                  selected: option == view,
                  onSelected: loading
                      ? null
                      : (selected) {
                          if (selected && option != view) {
                            setState(() => view = option);
                            fetch(from, to);
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 16),
          specialties.when(
            loading: () => const Text('Cargando especialidades'),
            error: (_, _) => Column(
              children: [
                const Text('No se pudieron cargar las especialidades.'),
                TextButton(
                  onPressed: () => ref.invalidate(specialtiesProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            data: (items) => DropdownButtonFormField<int>(
              initialValue: specialtyId,
              decoration: const InputDecoration(labelText: 'Especialidad'),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                for (final item in items)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() => specialtyId = value);
                      fetch(from, to);
                    },
            ),
          ),
          const SizedBox(height: 16),
          PeriodFilter(
            fromController: fromController,
            toController: toController,
            onFromChanged: (value) => from = value,
            onToChanged: (value) => to = value,
            onConsult: loading ? null : consult,
            errorText: periodError,
          ),
          const SizedBox(height: 24),
          if (loading)
            const Text('Calculando estadísticas', key: Key('stats-loading'))
          else if (error != null)
            Column(
              children: [
                Text(error!, key: const Key('stats-error')),
                TextButton(
                  onPressed: () => fetch(requestedFrom, requestedTo),
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else if (result case final data?) ...[
            PeriodLabel(from: data.from, to: data.to),
            const SizedBox(height: 12),
            if (data.cells.isEmpty)
              const Text('Sin datos', key: Key('stats-empty'))
            else
              _Heatmap(cells: data.cells),
          ],
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.cells});
  final List<TimeSlotCell> cells;
  static const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  @override
  Widget build(BuildContext context) {
    final counts = <(int, int), int>{};
    for (final cell in cells) {
      counts[(cell.day, cell.hour)] = cell.count;
    }
    final maxCount = cells.fold<int>(
      0,
      (max, c) => c.count > max ? c.count : max,
    );
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cantidad por día y hora (hora de Uruguay)'),
        const Text('Color más intenso: mayor cantidad'),
        const Text('Deslizá horizontalmente para ver todos los días'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 80),
                  for (final day in days)
                    SizedBox(width: 58, child: Center(child: Text(day))),
                ],
              ),
              for (var hour = 0; hour < 24; hour++)
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00–${(hour + 1).toString().padLeft(2, '0')}:00',
                      ),
                    ),
                    for (var day = 1; day <= 7; day++)
                      Builder(
                        builder: (context) {
                          final count = counts[(day, hour)];
                          final intensity = count == null || maxCount == 0
                              ? 0.0
                              : count / maxCount;
                          return Semantics(
                            label:
                                '${days[day - 1]} $hour:00, ${count?.toString() ?? "sin datos"}',
                            child: Container(
                              width: 56,
                              height: 32,
                              margin: const EdgeInsets.all(1),
                              color: Color.alphaBlend(
                                color.withValues(alpha: intensity * 0.4),
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              child: Center(
                                child: Text(count?.toString() ?? '–'),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
