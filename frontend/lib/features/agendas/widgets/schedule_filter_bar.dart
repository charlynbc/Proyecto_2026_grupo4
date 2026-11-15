import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../auth/widgets/credential_fields.dart';
import '../../turnos/providers/doctors_provider.dart';
import '../models/schedule_filters.dart';
import '../models/schedule_status_label.dart';
import '../providers/schedule_filters_controller.dart';
import '../providers/schedules_today_provider.dart';

/// Desde cuándo se puede elegir la fecha en el calendario.
final DateTime kSchedulePickerFirstDate = DateTime.utc(2020, 1, 1);

String _orderLabel(ScheduleOrder order) => switch (order) {
  ScheduleOrder.dateTime => 'Fecha y hora',
  ScheduleOrder.arrivalTime => 'Hora de llegada',
};

String? _blankToNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Filtros de la consulta de agendas (RF-18): cédula, número de consulta,
/// fecha, médico, estado y llegada se aplican juntos con "Buscar"; el orden y
/// el sentido se aplican apenas se cambian. Es el mismo criterio que la barra
/// de la consulta de turnos.
///
/// La cédula y la fecha se validan al buscar: con un dato mal escrito no se
/// busca y el propio campo muestra el error. La cédula y la fecha vacías no
/// son un error, son "sin filtro": con la fecha vacía se ven las consultas de
/// todos los días (la fecha empieza con hoy y se borra con la cruz del campo).
class ScheduleFilterBar extends ConsumerStatefulWidget {
  const ScheduleFilterBar({super.key});

  @override
  ConsumerState<ScheduleFilterBar> createState() => _ScheduleFilterBarState();
}

class _ScheduleFilterBarState extends ConsumerState<ScheduleFilterBar> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ciController;
  late final TextEditingController _idController;
  late final TextEditingController _dateController;
  int? _doctorId;
  String? _status;
  bool? _arrived;

  /// Mientras valida al buscar, el campo de fecha informa su error de formato
  /// aunque todavía tenga el foco (ver `UiDateField.showErrorsNow`).
  bool _validatingNow = false;

  /// Cambia al limpiar: los campos se arman de nuevo, sin errores viejos.
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    final applied = ref.read(scheduleFiltersControllerProvider);
    _ciController = TextEditingController(text: applied.ci ?? '');
    _idController = TextEditingController(text: applied.appointmentId ?? '');
    _dateController = TextEditingController(
      text: applied.date == null ? '' : formatUiDate(applied.date!),
    );
    _doctorId = applied.doctorId;
    _status = applied.status;
    _arrived = applied.arrived;
  }

  @override
  void dispose() {
    _ciController.dispose();
    _idController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// La cédula vacía es "sin filtro"; escrita, tiene que ser válida.
  String? _validateCi(String? value) =>
      (value ?? '').trim().isEmpty ? null : CiFormField.validate(value);

  void _search() {
    // Tocar "Buscar" no mueve el foco de los campos: se lo suelta acá para que
    // un campo a medias muestre su error y en Android se cierre el teclado.
    FocusScope.of(context).unfocus();

    _validatingNow = true;
    final valid = _formKey.currentState?.validate() ?? false;
    _validatingNow = false;
    if (!valid) return;

    ref.read(scheduleFiltersControllerProvider.notifier)
      ..setCi(_blankToNull(_ciController.text))
      ..setAppointmentId(_blankToNull(_idController.text))
      ..setDoctorId(_doctorId)
      // Vacía es "todos los días"; escrita, ya pasó la validación del campo.
      ..setDate(parseUiDate(_dateController.text.trim()))
      ..setStatus(_status)
      ..setArrived(_arrived);
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    final today = ref.read(schedulesTodayProvider);
    _ciController.clear();
    _idController.clear();
    _dateController.text = formatUiDate(today);
    setState(() {
      _doctorId = null;
      _status = null;
      _arrived = null;
      _epoch++;
    });
    ref.read(scheduleFiltersControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(scheduleFiltersControllerProvider);
    final controller = ref.read(scheduleFiltersControllerProvider.notifier);
    final today = ref.watch(schedulesTodayProvider);
    // Si los médicos están cargando o no llegaron, el desplegable ofrece solo
    // "Todos" y el resto de la pantalla sigue andando.
    final doctors = ref.watch(doctorsProvider).value ?? const [];
    // El campo del número de consulta crece con el texto del sistema, para que
    // su etiqueta no se corte, sin pasar del ancho de la pantalla.
    final idWidth = math.max(
      160.0,
      math.min(
        MediaQuery.textScalerOf(context).scale(160),
        MediaQuery.sizeOf(context).width - 32,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Form(
          key: _formKey,
          child: Wrap(
            key: ValueKey(_epoch),
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: 210,
                child: CiFormField(
                  key: const Key('filter-ci'),
                  controller: _ciController,
                  validator: _validateCi,
                ),
              ),
              SizedBox(
                width: idWidth,
                child: TextFormField(
                  key: const Key('filter-id'),
                  controller: _idController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'N.º de consulta',
                  ),
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _search(),
                ),
              ),
              SizedBox(
                width: 220,
                child: UiDateField(
                  key: const Key('filter-date'),
                  controller: _dateController,
                  label: 'Fecha',
                  pickerHelpText: 'Fecha de las consultas',
                  pickerTooltip: 'Elegir la fecha',
                  firstDate: kSchedulePickerFirstDate,
                  // Hasta un año después de hoy.
                  lastDate: DateTime.utc(
                    today.year + 1,
                    today.month,
                    today.day,
                  ),
                  today: () => today,
                  showErrorsNow: () => _validatingNow,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<int?>(
                  key: const Key('filter-doctor'),
                  initialValue: doctors.any((d) => d.id == _doctorId)
                      ? _doctorId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Médico'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final doctor in doctors)
                      DropdownMenuItem(
                        value: doctor.id,
                        child: Text(doctor.fullName),
                      ),
                  ],
                  onChanged: (value) => setState(() => _doctorId = value),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  key: const Key('filter-status'),
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    for (final entry in kScheduleStatusLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<bool?>(
                  key: const Key('filter-arrived'),
                  initialValue: _arrived,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Llegada'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Con aviso de llegada'),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text('Sin aviso de llegada'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _arrived = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Limpiar'),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<ScheduleOrder>(
                  key: const Key('filter-order'),
                  initialValue: applied.order,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ordenar por'),
                  items: [
                    for (final order in ScheduleOrder.values)
                      DropdownMenuItem(
                        value: order,
                        child: Text(_orderLabel(order)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) controller.setOrder(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  onPressed: () => controller.setAscending(!applied.ascending),
                  icon: Icon(
                    applied.ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                  label: Text(applied.ascending ? 'Ascendente' : 'Descendente'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _dateHelp(context),
      ],
    );
  }

  /// Aclara qué pasa con la fecha: empieza en hoy y la cruz del campo la borra
  /// para ver las consultas de todos los días.
  Widget _dateHelp(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _dateController,
      builder: (context, value, _) => Text(
        value.text.trim().isEmpty
            ? 'Sin fecha se ven las consultas de todos los días.'
            : 'Para ver todos los días, borrá la fecha con la cruz.',
        key: const Key('filter-date-help'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
