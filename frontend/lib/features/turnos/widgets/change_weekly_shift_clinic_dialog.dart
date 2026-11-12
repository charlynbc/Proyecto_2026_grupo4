import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../consultorios/models/clinic.dart';
import '../../consultorios/providers/clinics_provider.dart';
import '../models/clinic_change_preview.dart';
import '../models/weekly_shift.dart';
import '../providers/change_weekly_shift_clinic_controller.dart';
import '../providers/weekly_shift_clinic_repository_provider.dart';

/// RF-20: el funcionario ve las fechas y decide cuáles cambiar.
class ChangeWeeklyShiftClinicDialog extends ConsumerStatefulWidget {
  const ChangeWeeklyShiftClinicDialog({super.key, required this.weeklyShift});

  final WeeklyShift weeklyShift;

  @override
  ConsumerState<ChangeWeeklyShiftClinicDialog> createState() =>
      _ChangeWeeklyShiftClinicDialogState();
}

class _ChangeWeeklyShiftClinicDialogState
    extends ConsumerState<ChangeWeeklyShiftClinicDialog> {
  late int _clinicId;
  final Set<int> _selectedTurnoIds = <int>{};
  ClinicChangePreview? _preview;
  bool _loadingPreview = false;
  bool _confirmarConConsultas = false;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _clinicId = widget.weeklyShift.clinic.id;
  }

  void _select(int? id) {
    if (id == null || id == _clinicId) return;
    setState(() {
      _clinicId = id;
      _preview = null;
      _previewError = null;
      _selectedTurnoIds.clear();
      _confirmarConConsultas = false;
    });
    ref.read(changeWeeklyShiftClinicControllerProvider.notifier).reset();
    _loadPreview();
  }

  /// La vista previa no guarda nada; cada cambio de consultorio la invalida.
  Future<void> _loadPreview() async {
    ref.read(changeWeeklyShiftClinicControllerProvider.notifier).reset();
    final requestedClinic = _clinicId;
    setState(() {
      _loadingPreview = true;
      _previewError = null;
      _preview = null;
      _selectedTurnoIds.clear();
      _confirmarConConsultas = false;
    });
    try {
      final repository = await ref.read(
        weeklyShiftClinicRepositoryProvider.future,
      );
      final result = await repository.previewClinicChange(
        widget.weeklyShift.id,
        requestedClinic,
      );
      if (!mounted || requestedClinic != _clinicId) return;
      setState(() {
        _preview = result;
        _selectedTurnoIds.addAll(
          result.dates
              .where((date) => _isSelectable(date))
              .map((date) => date.shiftId),
        );
      });
    } catch (error) {
      if (!mounted || requestedClinic != _clinicId) return;
      setState(() => _previewError = apiMessageOf(error));
    } finally {
      if (mounted && requestedClinic == _clinicId) {
        setState(() => _loadingPreview = false);
      }
    }
  }

  bool _isSelectable(ClinicChangePreviewDate date) =>
      !date.hasOverlaps &&
      (date.currentClinicId == null || date.currentClinicId != _clinicId);

  void _toggleTurno(int turnoId, bool seleccionado) {
    setState(() {
      if (seleccionado) {
        _selectedTurnoIds.add(turnoId);
      } else {
        _selectedTurnoIds.remove(turnoId);
      }
      // Si cambia la selección, el consentimiento tiene que darse otra vez.
      _confirmarConConsultas = false;
    });
  }

  Future<void> _save() async {
    final dates = _preview?.dates ?? const <ClinicChangePreviewDate>[];
    final chosen = [
      for (final date in dates)
        if (_selectedTurnoIds.contains(date.shiftId) && _isSelectable(date))
          date.shiftId,
    ];
    if (chosen.isEmpty) return;
    final updated = await ref
        .read(changeWeeklyShiftClinicControllerProvider.notifier)
        .submit(
          widget.weeklyShift.id,
          _clinicId,
          turnoIds: chosen,
          confirmarConConsultas: _confirmarConConsultas,
        );
    if (updated != null && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeWeeklyShiftClinicControllerProvider);
    final clinics = ref.watch(clinicsProvider);
    final current = widget.weeklyShift.clinic;
    final dates = _preview?.dates ?? const <ClinicChangePreviewDate>[];
    final bookedSelected = dates
        .where((date) => _selectedTurnoIds.contains(date.shiftId))
        .fold<int>(0, (total, date) => total + date.bookedAppointments);
    final canSave =
        clinics.hasValue &&
        _preview != null &&
        _selectedTurnoIds.isNotEmpty &&
        (bookedSelected == 0 || _confirmarConConsultas) &&
        !_loadingPreview &&
        !state.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: const Text('Cambiar consultorio'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consultorio actual: ${current.name} (${current.location}). '
              'Cambia las fechas de hoy en adelante; las fechas pasadas '
              'conservan su consultorio.',
            ),
            const SizedBox(height: 16),
            if (clinics.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (clinics.hasError)
              _ClinicsNotice(
                message:
                    'No pudimos cargar los consultorios. Intentá de nuevo.',
                onRetry: () => ref.invalidate(clinicsProvider),
              )
            else
              DropdownButtonFormField<int>(
                key: const Key('weekly-shift-clinic-select'),
                initialValue: _listed(_clinicId, clinics.value!),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Consultorio nuevo',
                ),
                items: [
                  for (final clinic in clinics.value!)
                    DropdownMenuItem(
                      value: clinic.id,
                      child: Text(clinic.name),
                    ),
                ],
                onChanged: _loadingPreview || state.isLoading ? null : _select,
              ),
            if (!_loadingPreview &&
                _preview == null &&
                _previewError == null &&
                clinics.hasValue)
              TextButton(
                onPressed: state.isLoading ? null : _loadPreview,
                child: const Text('Consultar fechas'),
              ),
            if (_loadingPreview) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_previewError != null) ...[
              const SizedBox(height: 12),
              Text(_previewError!, style: TextStyle(color: colorScheme.error)),
              TextButton(
                onPressed: _loadingPreview ? null : _loadPreview,
                child: const Text('Reintentar vista previa'),
              ),
            ],
            if (_preview != null) ...[
              const SizedBox(height: 16),
              Text(
                'Fechas de hoy en adelante',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              if (dates.isEmpty)
                const Text('No hay fechas actuales ni futuras para cambiar.')
              else ...[
                Text(
                  'Seleccionadas: ${_selectedTurnoIds.length} de ${dates.length}. '
                  'Las fechas con solapamiento no se pueden seleccionar.',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 270,
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: dates.length,
                    itemBuilder: (context, index) {
                      final date = dates[index];
                      final selectable = _isSelectable(date);
                      final overlapText = date.overlaps
                          .map(
                            (overlap) =>
                                'Número ${overlap.ownNumber} con número ${overlap.existingNumber}',
                          )
                          .join('; ');
                      return CheckboxListTile(
                        key: Key('weekly-shift-date-${date.shiftId}'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _selectedTurnoIds.contains(date.shiftId),
                        onChanged: selectable && !state.isLoading
                            ? (value) =>
                                  _toggleTurno(date.shiftId, value ?? false)
                            : null,
                        title: Text(formatUiDate(date.date)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${date.state.label} · Consultorio actual: '
                              '${date.currentClinicName ?? date.currentClinicId?.toString() ?? "sin dato"}',
                            ),
                            if (date.bookedAppointments > 0)
                              Text(
                                '${date.bookedAppointments} consulta(s) agendada(s)',
                              ),
                            if (date.hasOverlaps)
                              Text(
                                'Solapamiento: $overlapText',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            if (!date.hasOverlaps && !selectable)
                              const Text('Ya usa el consultorio elegido.'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: state.isLoading ? null : _loadPreview,
                  child: const Text('Actualizar vista previa'),
                ),
              ],
            ],
            if (bookedSelected > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Atención: hay $bookedSelected consulta(s) agendada(s) en las fechas elegidas. '
                'Por ahora el cambio no notificará automáticamente a los socios.',
                style: TextStyle(color: colorScheme.error),
              ),
              CheckboxListTile(
                key: const Key('weekly-shift-confirm-booked'),
                contentPadding: EdgeInsets.zero,
                value: _confirmarConConsultas,
                onChanged: state.isLoading
                    ? null
                    : (value) => setState(
                        () => _confirmarConConsultas = value ?? false,
                      ),
                title: const Text(
                  'Confirmo el cambio con consultas agendadas.',
                ),
              ),
            ],
            if (state.status == SubmitStatus.error &&
                state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('weekly-shift-clinic-error'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('weekly-shift-clinic-cancel'),
          onPressed: state.isLoading
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('weekly-shift-clinic-save'),
          onPressed: canSave ? _save : null,
          child: state.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

int? _listed(int clinicId, List<Clinic> clinics) =>
    clinics.any((clinic) => clinic.id == clinicId) ? clinicId : null;

class _ClinicsNotice extends StatelessWidget {
  const _ClinicsNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
