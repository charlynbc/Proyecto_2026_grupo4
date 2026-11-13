import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/sort_direction_button.dart';
import '../../agenda/models/agenda_time.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/doctor_shift.dart';
import '../providers/doctor_agenda_controller.dart';
import '../widgets/doctor_number_actions.dart';
import '../widgets/cancel_shift_button.dart';
import 'doctor_result_routes.dart';

/// "Mis turnos" del médico (RF-21): fecha, turnos propios, números con sus
/// pacientes, filtro por aviso de llegada y orden. La lista se actualiza sola
/// mientras la pantalla está a la vista.
class DoctorShiftsScreen extends ConsumerStatefulWidget {
  const DoctorShiftsScreen({super.key});

  @override
  ConsumerState<DoctorShiftsScreen> createState() => _DoctorShiftsScreenState();
}

class _DoctorShiftsScreenState extends ConsumerState<DoctorShiftsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    ref
        .read(doctorAgendaControllerProvider.notifier)
        .setVisible(lifecycle == AppLifecycleState.resumed);
  }

  Future<void> _pickDate(DoctorAgendaState state) async {
    final key = parseApiDate(state.date);
    final current = DateTime(key.year, key.month, key.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 2),
      helpText: 'Fecha de los turnos',
    );
    if (picked == null || !mounted) return;
    await ref
        .read(doctorAgendaControllerProvider.notifier)
        .setDate(formatApiDate(picked));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorAgendaControllerProvider);
    final controller = ref.read(doctorAgendaControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis turnos'),
        actions: const [LogoutButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Fecha: ${formatUiDate(parseApiDate(state.date))}',
                key: const Key('doctor-date'),
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Wrap y no Row: con texto grande o a 320 px los botones bajan de
              // renglón en vez de apretar o cortar la fecha.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('doctor-date-button'),
                    onPressed: () => _pickDate(state),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Cambiar fecha'),
                  ),
                  IconButton(
                    key: const Key('doctor-refresh'),
                    tooltip: 'Actualizar',
                    onPressed: controller.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (state.updatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Se actualiza automáticamente. Última actualización: '
                    '${_clock(state.updatedAt!)}',
                    key: const Key('doctor-updated-at'),
                    style: textTheme.bodySmall,
                  ),
                ),
              if (state.refreshError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: MaterialBanner(
                    key: const Key('doctor-refresh-error'),
                    content: Text(
                      '${state.refreshError} Se muestran los últimos datos y '
                      'se reintenta solo.',
                    ),
                    actions: const [SizedBox.shrink()],
                  ),
                ),
              const SizedBox(height: 16),
              if (state.loading && state.shifts == null)
                const Center(child: CircularProgressIndicator())
              else if (state.error != null)
                _ErrorBox(message: state.error!, onRetry: controller.refresh)
              else
                ..._content(state, controller, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    DoctorAgendaState state,
    DoctorAgendaController controller,
    TextTheme textTheme,
  ) {
    final shifts = state.shifts ?? const <DoctorShift>[];
    if (shifts.isEmpty) {
      return [
        Text(
          'No tenés turnos en esta fecha.',
          key: const Key('doctor-no-shifts'),
          style: textTheme.bodyLarge,
        ),
      ];
    }
    return [
      Text('Turnos del día', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final shift in shifts)
        Card(
          key: Key('doctor-shift-${shift.id}'),
          color: shift.id == state.selectedShiftId
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
          child: ListTile(
            title: Text(
              '${shift.startTime}–${shift.endTime} · ${shift.specialtyName}',
            ),
            subtitle: Text(
              '${shift.clinicName} · ${shift.reservedCount} de '
              '${shift.numbersCount} números reservados'
              '${shift.status == 'ACTIVO' ? '' : ' · Suspendido'}',
            ),
            trailing: CancelShiftButton(shift: shift),
            onTap: () => controller.selectShift(shift.id),
          ),
        ),
      if (state.selectedShiftId != null) ...[
        const SizedBox(height: 16),
        ..._numbers(state, controller, textTheme),
      ],
    ];
  }

  List<Widget> _numbers(
    DoctorAgendaState state,
    DoctorAgendaController controller,
    TextTheme textTheme,
  ) {
    final numbers = state.numbers;
    return [
      Text('Números del turno', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            key: const Key('arrived-filter-all'),
            label: const Text('Todos'),
            selected: state.arrivedFilter == null,
            onSelected: (_) => controller.setArrivedFilter(null),
          ),
          ChoiceChip(
            key: const Key('arrived-filter-yes'),
            label: const Text('Con aviso de llegada'),
            selected: state.arrivedFilter == true,
            onSelected: (_) => controller.setArrivedFilter(true),
          ),
          ChoiceChip(
            key: const Key('arrived-filter-no'),
            label: const Text('Sin aviso de llegada'),
            selected: state.arrivedFilter == false,
            onSelected: (_) => controller.setArrivedFilter(false),
          ),
          SegmentedButton<DoctorNumbersOrder>(
            key: const Key('doctor-order'),
            segments: [
              for (final order in DoctorNumbersOrder.values)
                ButtonSegment(value: order, label: Text(order.label)),
            ],
            selected: {state.order},
            onSelectionChanged: (selection) => controller.setOrder(
              selection.first,
              ascending: state.ascending,
            ),
          ),
          Tooltip(
            message: state.ascending ? 'Orden ascendente' : 'Orden descendente',
            child: SortDirectionButton(
              key: const Key('doctor-direction'),
              ascending: state.ascending,
              onPressed: () =>
                  controller.setOrder(state.order, ascending: !state.ascending),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (numbers == null)
        const Center(child: CircularProgressIndicator())
      else if (numbers.items.isEmpty)
        Text(
          'No hay números para este filtro.',
          key: const Key('doctor-no-numbers'),
          style: textTheme.bodyLarge,
        )
      else
        for (final item in numbers.items) _NumberTile(item: item),
    ];
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.item});

  final DoctorShiftNumber item;

  bool get _canOpenResult {
    final status = item.appointmentStatus?.toUpperCase();
    return item.appointmentId != null &&
        status == 'AGENDADA' &&
        item.arrivedAt != null;
  }

  @override
  Widget build(BuildContext context) {
    final patient = item.patient;
    return Card(
      child: ListTile(
        key: Key('doctor-number-${item.number}'),
        enabled: _canOpenResult,
        onTap: _canOpenResult
            ? () => context.push(
                doctorResultLocation(
                  item.appointmentId!,
                  patientName: patient == null
                      ? null
                      : '${patient.name} ${patient.lastName}',
                ),
              )
            : null,
        leading: CircleAvatar(child: Text('${item.number}')),
        title: Text(
          patient == null
              ? 'Sin reserva'
              : '${patient.name} ${patient.lastName} · CI ${patient.ci}',
        ),
        subtitle: Text(
          patient == null
              ? '${item.startTime}–${item.endTime}'
              : '${item.startTime}–${item.endTime} · '
                    '${_statusLabel(item.appointmentStatus)} · '
                    '${item.arrivedAt == null ? 'Sin aviso de llegada' : 'Llegó a las ${_clock(item.arrivedAt!)}'}',
        ),
        trailing: DoctorNumberActions(item: item),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          key: const Key('doctor-error'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('doctor-retry'),
          onPressed: onRetry,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}

String _clock(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _statusLabel(String? status) => switch (status) {
  'AGENDADA' => 'Agendada',
  'ATENDIDA' => 'Atendida',
  'NO_SE_PRESENTO' => 'No se presentó',
  'NO_ASISTIO' => 'No asistió',
  'NO_ATENDIDA' => 'No atendida',
  _ => status ?? '',
};
