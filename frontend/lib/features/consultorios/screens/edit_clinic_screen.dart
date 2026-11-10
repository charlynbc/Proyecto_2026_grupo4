import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/centered_content.dart';
import '../models/clinic.dart';
import '../providers/correct_clinic_controller.dart';
import '../providers/clinic_search_provider.dart';
import '../providers/clinics_provider.dart';
import '../repositories/clinic_correction_repository.dart';
import 'clinics_screen.dart';

class EditClinicScreen extends ConsumerStatefulWidget {
  const EditClinicScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<EditClinicScreen> createState() => _EditClinicScreenState();
}

class _EditClinicScreenState extends ConsumerState<EditClinicScreen> {
  static const int _maxNameLength = 120;
  static const int _maxLocationLength = 200;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  Clinic? _clinic;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  void _initialize(Clinic clinic) {
    if (_clinic?.id == clinic.id) return;
    _clinic = clinic;
    _nameController.text = clinic.name;
    _locationController.text = clinic.location;
  }

  bool _hasChanges(Clinic clinic) =>
      _nameController.text.trim() != clinic.name.trim() ||
      _locationController.text.trim() != clinic.location.trim();

  Future<void> _submit(Clinic clinic) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    await ref
        .read(correctClinicControllerProvider.notifier)
        .correct(
          clinic.id,
          name: name == clinic.name.trim() ? null : name,
          location: location == clinic.location.trim() ? null : location,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(correctClinicControllerProvider, (previous, state) {
      if (state.status == SubmitStatus.done) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Consultorio corregido.')));
        context.go(kClinicsPath);
      }
      if (state.failure == ClinicCorrectionFailure.notFound &&
          previous?.failure != ClinicCorrectionFailure.notFound) {
        ref.invalidate(clinicsProvider);
      }
    });
    final state = ref.watch(correctClinicControllerProvider);
    // Keep the covered list's derived data live while its search is invalidated.
    ref.watch(clinicListProvider);
    final clinics = ref.watch(clinicsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kClinicsPath),
        ),
        title: const Text('Corregir consultorio'),
      ),
      body: CenteredContent(
        child: clinics.when(
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('No pudimos cargar el consultorio.'),
              OutlinedButton(
                onPressed: () => ref.invalidate(clinicsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (items) {
            Clinic? clinic;
            for (final item in items) {
              if (item.id == widget.id) {
                clinic = item;
                break;
              }
            }
            if (clinic == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('No encontramos ese consultorio.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('edit-clinic-back'),
                    onPressed: () => context.go(kClinicsPath),
                    child: const Text('Volver a Consultorios'),
                  ),
                ],
              );
            }
            _initialize(clinic);
            return _form(context, clinic, state);
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context, Clinic clinic, CorrectClinicState state) {
    final enabled = !state.isLoading;
    final duplicateMessage = state.failure == ClinicCorrectionFailure.duplicate
        ? state.errorMessage
        : null;
    final topError =
        state.status == SubmitStatus.error &&
            state.failure != ClinicCorrectionFailure.duplicate
        ? state.errorMessage ?? kApiGenericMessage
        : null;
    final hasChanges = _hasChanges(clinic);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topError != null) ...[
            Text(
              topError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _nameController,
            enabled: enabled,
            maxLength: _maxNameLength,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nombre o número'),
            validator: (value) =>
                _required(value, 'Ingresá el nombre o número del consultorio.'),
            onChanged: (_) {
              if (duplicateMessage != null) {
                ref.read(correctClinicControllerProvider.notifier).clearError();
              }
              setState(() {});
            },
          ),
          if (duplicateMessage != null) ...[
            Text(
              duplicateMessage,
              key: const Key('edit-clinic-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _locationController,
            enabled: enabled,
            maxLength: _maxLocationLength,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Ubicación (piso o sector)',
            ),
            validator: (value) => _required(value, 'Ingresá la ubicación.'),
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) => _submit(clinic),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('edit-clinic-save'),
            onPressed: enabled && hasChanges ? () => _submit(clinic) : null,
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: enabled ? () => context.go(kClinicsPath) : null,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
