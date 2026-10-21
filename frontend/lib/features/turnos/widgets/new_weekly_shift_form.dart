import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../consultorios/providers/clinics_provider.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/new_weekly_shift.dart';
import '../models/shift_date_range.dart';
import '../models/shift_number.dart';
import '../models/shift_numbers_rules.dart';
import '../models/weekday_names.dart';
import '../providers/create_weekly_shift_controller.dart';
import '../providers/doctors_by_specialty_provider.dart';
import '../screens/shift_routes.dart';
import 'shift_numbers_editor.dart';

const String _fromAfterTo =
    'La fecha de inicio no puede ser posterior a la de fin.';

/// Formulario del alta de un turno semanal (RF-13, CU 3.3.1). El cliente valida
/// para ayudar; las reglas definitivas, incluidos los cruces con otros turnos,
/// son del servidor.
///
/// Al guardar se valida en este orden, con un solo mensaje por causa: los
/// campos obligatorios (debajo de su campo); que "desde" no sea posterior a
/// "hasta"; que la vigencia tenga al menos una fecha del día elegido (estas dos
/// solo si las dos fechas son válidas); y los números, en el editor. El formato
/// de cada fecha lo valida el propio campo de fecha.
class NewWeeklyShiftForm extends ConsumerStatefulWidget {
  const NewWeeklyShiftForm({super.key});

  @override
  ConsumerState<NewWeeklyShiftForm> createState() => _NewWeeklyShiftFormState();
}

class _NewWeeklyShiftFormState extends ConsumerState<NewWeeklyShiftForm> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  int? _specialtyId;
  int? _doctorId;
  int? _clinicId;
  int? _weekday;
  List<ShiftNumber> _numbers = [];

  /// Ya se intentó guardar: desde ahí se reclama el editor vacío.
  bool _attempted = false;

  /// Solo es verdadero mientras `_submit` corre `Form.validate()`.
  bool _validatingSubmit = false;
  String? _rangeError;
  String? _weekdayError;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  /// "Obligatoria" se reclama recién después del primer intento de guardar, no
  /// apenas se vacía el campo.
  String? _requiredDate(String? value, String message) =>
      _attempted && (value ?? '').trim().isEmpty ? message : null;

  String? _required(Object? value, String message) =>
      value == null ? message : null;

  /// Al tocar la vigencia o el día, los avisos de rango y de día dejan de
  /// corresponder: se vuelven a calcular al guardar.
  void _clearCrossErrors() {
    if (_rangeError != null || _weekdayError != null) {
      setState(() {
        _rangeError = null;
        _weekdayError = null;
      });
    }
  }

  Future<void> _submit() async {
    final controller = ref.read(createWeeklyShiftControllerProvider.notifier);
    if (ref.read(createWeeklyShiftControllerProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    // El aviso del servidor de un intento anterior ya no corresponde.
    controller.reset();

    final from = parseUiDate(_fromController.text.trim());
    final to = parseUiDate(_toController.text.trim());
    String? rangeError;
    String? weekdayError;
    if (from != null && to != null) {
      if (from.isAfter(to)) {
        rangeError = _fromAfterTo;
      } else if (_weekday != null &&
          countWeekdayDates(from, to, _weekday!) == 0) {
        weekdayError =
            'Entre el ${formatUiDate(from)} y el ${formatUiDate(to)} no hay '
            'ningún ${weekdayName(_weekday!)}. Elegí otro día o ampliá las '
            'fechas.';
      }
    }
    // Al guardar, los números quedan ordenados por hora y numerados 1, 2, 3
    // también en pantalla, así el N.º que nombra un aviso del servidor es el
    // de la fila de esa posición. Vale aunque el guardado después falle.
    final sorted = sortNumbers(_numbers);
    final ordered = [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWith(number: i + 1),
    ];
    setState(() {
      _attempted = true;
      _rangeError = rangeError;
      _weekdayError = weekdayError;
      _numbers = ordered;
    });

    // Soltar el foco no es inmediato: mientras se valida, los campos de fecha
    // tienen que avisar de una fecha a medias aunque todavía "tengan" el foco.
    _validatingSubmit = true;
    final bool formValid;
    try {
      formValid = _formKey.currentState?.validate() ?? false;
    } finally {
      _validatingSubmit = false;
    }
    if (!formValid ||
        rangeError != null ||
        weekdayError != null ||
        validateNumbers(_numbers).isNotEmpty) {
      return;
    }

    final created = await controller.submit(
      NewWeeklyShift(
        doctorId: _doctorId!,
        specialtyId: _specialtyId!,
        clinicId: _clinicId!,
        weekday: _weekday!,
        startDate: from!,
        endDate: to!,
        numbers: ordered,
      ),
    );
    if (!mounted || created == null) return;
    final count = created.shiftCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se creó el turno semanal con $count '
          '${count == 1 ? 'fecha' : 'fechas'}.',
        ),
      ),
    );
    context.go(weeklyShiftDetailLocation(created.id));
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(createWeeklyShiftControllerProvider);
    final enabled = !submit.isLoading;
    final specialties = ref.watch(specialtiesProvider);
    final clinics = ref.watch(clinicsProvider);
    final doctors = _specialtyId == null
        ? null
        : ref.watch(doctorsBySpecialtyProvider(_specialtyId!));
    final doctorList = doctors?.value ?? const [];
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (submit.errorMessage != null) ...[
            Container(
              key: const Key('server-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                submit.errorMessage!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<int>(
            key: const Key('field-specialty'),
            initialValue:
                specialties.value?.any((s) => s.id == _specialtyId) == true
                ? _specialtyId
                : null,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Especialidad'),
            items: [
              for (final specialty in specialties.value ?? const [])
                DropdownMenuItem(
                  value: specialty.id,
                  child: Text(specialty.name),
                ),
            ],
            validator: (v) => _required(v, 'Elegí la especialidad.'),
            onChanged: enabled
                ? (value) => setState(() {
                    _specialtyId = value;
                    // El médico elegido puede no ejercer la nueva especialidad.
                    _doctorId = null;
                  })
                : null,
          ),
          if (specialties.hasError)
            _CatalogError(
              message:
                  'No pudimos cargar las especialidades. Intentá de nuevo.',
              onRetry: () => ref.invalidate(specialtiesProvider),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const Key('field-doctor'),
            initialValue: doctorList.any((d) => d.id == _doctorId)
                ? _doctorId
                : null,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Médico'),
            items: [
              for (final doctor in doctorList)
                DropdownMenuItem(
                  value: doctor.id,
                  child: Text(doctor.fullName),
                ),
            ],
            validator: (v) => _required(v, 'Elegí el médico.'),
            onChanged: enabled && doctorList.isNotEmpty
                ? (value) => setState(() => _doctorId = value)
                : null,
          ),
          if (doctors != null && doctors.hasError)
            _CatalogError(
              message: 'No pudimos cargar los médicos. Intentá de nuevo.',
              onRetry: () =>
                  ref.invalidate(doctorsBySpecialtyProvider(_specialtyId!)),
            ),
          if (doctors != null && doctors.hasValue && doctorList.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No hay médicos activos con esa especialidad.'),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const Key('field-clinic'),
            initialValue: clinics.value?.any((c) => c.id == _clinicId) == true
                ? _clinicId
                : null,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Consultorio'),
            items: [
              for (final clinic in clinics.value ?? const [])
                DropdownMenuItem(value: clinic.id, child: Text(clinic.name)),
            ],
            validator: (v) => _required(v, 'Elegí el consultorio.'),
            onChanged: enabled
                ? (value) => setState(() => _clinicId = value)
                : null,
          ),
          if (clinics.hasError)
            _CatalogError(
              message: 'No pudimos cargar los consultorios. Intentá de nuevo.',
              onRetry: () => ref.invalidate(clinicsProvider),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const Key('field-weekday'),
            initialValue: _weekday,
            isExpanded: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Día de la semana'),
            items: [
              for (var day = 1; day <= 7; day++)
                DropdownMenuItem(value: day, child: Text(weekdayLabel(day))),
            ],
            validator: (v) => _required(v, 'Elegí el día de la semana.'),
            onChanged: enabled
                ? (value) {
                    _clearCrossErrors();
                    setState(() => _weekday = value);
                  }
                : null,
          ),
          const SizedBox(height: 16),
          UiDateField(
            key: const Key('field-from'),
            controller: _fromController,
            enabled: enabled,
            label: 'Vigencia desde (dd/mm/aaaa)',
            pickerHelpText: 'Vigencia desde',
            pickerTooltip: 'Elegir la fecha de inicio de la vigencia',
            firstDate: kShiftDatePickerFirstDate,
            lastDate: kShiftDatePickerLastDate,
            textInputAction: TextInputAction.next,
            showErrorsNow: () => _validatingSubmit,
            validator: (v) => _requiredDate(v, 'Ingresá la fecha de inicio.'),
            onChanged: (_) => _clearCrossErrors(),
          ),
          const SizedBox(height: 16),
          UiDateField(
            key: const Key('field-to'),
            controller: _toController,
            enabled: enabled,
            label: 'Vigencia hasta (dd/mm/aaaa)',
            pickerHelpText: 'Vigencia hasta',
            pickerTooltip: 'Elegir la fecha de fin de la vigencia',
            firstDate: kShiftDatePickerFirstDate,
            lastDate: kShiftDatePickerLastDate,
            // El calendario de "hasta" abre en la fecha de "desde", si es válida.
            initialPickerDate: () => parseUiDate(_fromController.text),
            textInputAction: TextInputAction.done,
            showErrorsNow: () => _validatingSubmit,
            validator: (v) =>
                _requiredDate(v, 'Ingresá la fecha de fin.') ?? _rangeError,
            onChanged: (_) => _clearCrossErrors(),
          ),
          if (_weekdayError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _weekdayError!,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          ShiftNumbersEditor(
            numbers: _numbers,
            showEmptyError: _attempted,
            onChanged: (value) => setState(() => _numbers = value),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              if (submit.isLoading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              TextButton(
                onPressed: enabled ? () => context.go(kShiftsPath) : null,
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: enabled ? _submit : null,
                child: const Text('Guardar turno'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// El aviso de un catálogo que no cargó, con su "Reintentar".
class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
