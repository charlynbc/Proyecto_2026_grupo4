import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../consultorios/models/clinic.dart';
import '../../consultorios/providers/clinics_provider.dart';
import '../models/weekly_shift.dart';
import '../providers/change_weekly_shift_clinic_controller.dart';

/// Elige el consultorio nuevo de una configuración semanal (RF-20).
///
/// Guardar queda apagado si el elegido es el actual, si el catálogo no cargó
/// o mientras se envía. Un error deja el diálogo abierto con el texto del
/// servidor; elegir otro consultorio lo borra.
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

  @override
  void initState() {
    super.initState();
    _clinicId = widget.weeklyShift.clinic.id;
  }

  void _select(int? id) {
    if (id == null) return;
    setState(() => _clinicId = id);
    if (ref.read(changeWeeklyShiftClinicControllerProvider).status ==
        SubmitStatus.error) {
      ref.read(changeWeeklyShiftClinicControllerProvider.notifier).reset();
    }
  }

  Future<void> _save() async {
    final updated = await ref
        .read(changeWeeklyShiftClinicControllerProvider.notifier)
        .submit(widget.weeklyShift.id, _clinicId);
    if (updated != null && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeWeeklyShiftClinicControllerProvider);
    final clinics = ref.watch(clinicsProvider);
    final current = widget.weeklyShift.clinic;
    final canSave =
        clinics.hasValue && _clinicId != current.id && !state.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: const Text('Cambiar consultorio'),
      content: Column(
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (clinics.hasError)
            _ClinicsNotice(
              message: 'No pudimos cargar los consultorios. Intentá de nuevo.',
              onRetry: () => ref.invalidate(clinicsProvider),
            )
          else
            DropdownButtonFormField<int>(
              key: const Key('weekly-shift-clinic-select'),
              initialValue: _listed(_clinicId, clinics.value!),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Consultorio nuevo'),
              items: [
                for (final clinic in clinics.value!)
                  DropdownMenuItem(value: clinic.id, child: Text(clinic.name)),
              ],
              onChanged: state.isLoading ? null : _select,
            ),
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
      actions: [
        TextButton(
          key: const Key('weekly-shift-clinic-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('weekly-shift-clinic-save'),
          onPressed: canSave ? _save : null,
          child: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
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
