import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/router/app_router.dart' show kDoctorShiftsPath;
import '../../../core/utils/ui_date.dart';
import '../../agenda/models/referral.dart';
import '../../especialidades/models/specialty.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/doctor_appointment_result.dart';
import '../providers/doctor_result_controller.dart';
import '../providers/referral_specialties_provider.dart';

/// Resultado de la consulta [appointmentId] (RF-23 y RF-24): si el paciente fue
/// atendido o no se presentó y, si fue atendido, la afección, el tratamiento,
/// las observaciones y los pases. El resultado es definitivo, así que antes de
/// enviarlo se pide una confirmación. [patientName] solo sirve para el
/// encabezado.
class DoctorAppointmentResultScreen extends ConsumerStatefulWidget {
  const DoctorAppointmentResultScreen({
    super.key,
    required this.appointmentId,
    this.patientName,
  });

  final int appointmentId;
  final String? patientName;

  @override
  ConsumerState<DoctorAppointmentResultScreen> createState() =>
      _DoctorAppointmentResultScreenState();
}

class _DoctorAppointmentResultScreenState
    extends ConsumerState<DoctorAppointmentResultScreen> {
  final TextEditingController _condition = TextEditingController();
  final TextEditingController _treatment = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _validity = TextEditingController();
  int? _selectedSpecialty;
  String? _pickError;

  @override
  void dispose() {
    _condition.dispose();
    _treatment.dispose();
    _notes.dispose();
    _validity.dispose();
    super.dispose();
  }

  DoctorResultController get _controller =>
      ref.read(doctorResultControllerProvider.notifier);

  void _addReferral() {
    final id = _selectedSpecialty;
    if (id == null) {
      setState(() => _pickError = 'Elegí la especialidad del pase.');
      return;
    }
    final added = _controller.addReferral(
      specialtyId: id,
      validityText: _validity.text,
    );
    setState(() {
      _pickError = null;
      if (added) {
        _selectedSpecialty = null;
        _validity.clear();
      }
    });
  }

  Future<void> _register() async {
    if (!_controller.validate()) return;
    final form = ref.read(doctorResultControllerProvider);
    // Un doble toque en Confirmar no cierra dos veces el diálogo.
    var answered = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        void answer(bool value) {
          if (answered) return;
          answered = true;
          Navigator.of(dialogContext).pop(value);
        }

        return AlertDialog(
          title: const Text('Confirmar el resultado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Se va a registrar: ${_summary(form)}.'),
              const SizedBox(height: 8),
              const Text(
                'Una vez registrado, el resultado no se puede cambiar.',
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('confirm-result-cancel'),
              onPressed: () => answer(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-result-ok'),
              onPressed: () => answer(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _controller.submit(widget.appointmentId);
  }

  static String _summary(DoctorResultFormState form) {
    if (form.outcome == ConsultationOutcome.noShow) return 'No se presentó';
    return switch (form.referrals.length) {
      0 => 'Atendida sin pases',
      1 => 'Atendida con 1 pase',
      final count => 'Atendida con $count pases',
    };
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(doctorResultControllerProvider);
    final result = form.result;
    final name = widget.patientName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a mis turnos',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(kDoctorShiftsPath),
        ),
        title: const Text('Resultado de la consulta'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (name != null && name.isNotEmpty) ...[
                  Text(
                    'Paciente: $name',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                if (form.status == SubmitStatus.done && result != null)
                  _Done(result: result)
                else
                  ..._formChildren(form),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _formChildren(DoctorResultFormState form) {
    final attended = form.outcome == ConsultationOutcome.attended;
    final colors = Theme.of(context).colorScheme;
    return [
      SegmentedButton<ConsultationOutcome>(
        key: const Key('result-outcome'),
        segments: const [
          ButtonSegment(
            value: ConsultationOutcome.attended,
            label: Text('Atendida'),
          ),
          ButtonSegment(
            value: ConsultationOutcome.noShow,
            label: Text('No se presentó'),
          ),
        ],
        selected: {form.outcome},
        onSelectionChanged: (selection) =>
            _controller.setOutcome(selection.first),
      ),
      const SizedBox(height: 16),
      if (attended) ...[
        TextField(
          key: const Key('result-condition'),
          controller: _condition,
          onChanged: _controller.setCondition,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Afección',
            errorText: form.conditionError,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('result-treatment'),
          controller: _treatment,
          onChanged: _controller.setTreatment,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Tratamiento'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('result-notes'),
          controller: _notes,
          onChanged: _controller.setNotes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Observaciones'),
        ),
        const SizedBox(height: 24),
        ..._referralsSection(form),
        const SizedBox(height: 24),
      ],
      if (form.status == SubmitStatus.error && form.errorMessage != null) ...[
        Container(
          key: const Key('result-error'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            form.errorMessage!,
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
        const SizedBox(height: 16),
      ],
      FilledButton(
        key: const Key('result-submit'),
        onPressed: form.isLoading ? null : _register,
        child: form.isLoading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Registrando'),
                ],
              )
            : const Text('Registrar resultado'),
      ),
    ];
  }

  List<Widget> _referralsSection(DoctorResultFormState form) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final specialties = ref.watch(referralSpecialtiesProvider);
    final referralError = _pickError ?? form.referralError;
    final names = {
      for (final specialty in specialties.value ?? const <Specialty>[])
        specialty.id: specialty.name,
    };

    return [
      Text('Pases', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      for (final referral in form.referrals)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      names[referral.specialtyId] ??
                          'Especialidad ${referral.specialtyId}',
                      style: textTheme.bodyLarge,
                    ),
                    Text(
                      'Vigencia: ${referral.validityDays} días',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                key: Key('remove-referral-${referral.specialtyId}'),
                onPressed: () =>
                    _controller.removeReferral(referral.specialtyId),
                child: const Text('Quitar'),
              ),
            ],
          ),
        ),
      specialties.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No pudimos cargar las especialidades.',
              style: TextStyle(color: colors.error),
            ),
            TextButton(
              onPressed: () => ref.invalidate(specialtiesProvider),
              child: const Text('Reintentar'),
            ),
          ],
        ),
        data: (all) {
          final added = {for (final r in form.referrals) r.specialtyId};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Especialidad'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const Key('referral-specialty'),
                    isExpanded: true,
                    value: _selectedSpecialty,
                    hint: const Text('Elegí la especialidad'),
                    items: [
                      for (final specialty in all)
                        if (!added.contains(specialty.id))
                          DropdownMenuItem(
                            value: specialty.id,
                            child: Text(specialty.name),
                          ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedSpecialty = value;
                      _pickError = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('referral-validity'),
                controller: _validity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Vigencia en días',
                  hintText: '$kDefaultReferralValidityDays',
                ),
              ),
              if (referralError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    referralError,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const Key('referral-add'),
                  onPressed: _addReferral,
                  child: const Text('Agregar pase'),
                ),
              ),
            ],
          );
        },
      ),
    ];
  }
}

/// La confirmación que reemplaza al formulario cuando el servidor registró el
/// resultado.
class _Done extends StatelessWidget {
  const _Done({required this.result});

  final AppointmentResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final attended = result.outcome == ConsultationOutcome.attended;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Resultado registrado', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          attended
              ? 'La consulta quedó registrada como atendida.'
              : 'La consulta quedó registrada: el paciente no se presentó.',
        ),
        const SizedBox(height: 16),
        if (attended && result.referrals.isEmpty)
          const Text('No se emitieron pases.'),
        if (result.referrals.isNotEmpty) ...[
          Text('Pases emitidos', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final referral in result.referrals) _IssuedReferral(referral),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('result-back-to-shifts'),
          onPressed: () => context.go(kDoctorShiftsPath),
          child: const Text('Volver a mis turnos'),
        ),
      ],
    );
  }
}

class _IssuedReferral extends StatelessWidget {
  const _IssuedReferral(this.referral);

  final Referral referral;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(referral.specialty.name, style: textTheme.bodyLarge),
          Text(
            'Vence el ${formatUiDate(referral.expiresOn)}',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
