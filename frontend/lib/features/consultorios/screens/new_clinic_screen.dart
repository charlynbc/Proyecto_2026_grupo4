import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/widgets/centered_content.dart';
import '../providers/create_clinic_controller.dart';
import 'clinics_screen.dart';

/// Alta de un consultorio (RF-33, CU 3.5.3).
class NewClinicScreen extends ConsumerStatefulWidget {
  const NewClinicScreen({super.key});

  @override
  ConsumerState<NewClinicScreen> createState() => _NewClinicScreenState();
}

class _NewClinicScreenState extends ConsumerState<NewClinicScreen> {
  static const int _maxNameLength = 120;
  static const int _maxLocationLength = 200;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(createClinicControllerProvider.notifier)
        .submit(
          name: _nameController.text.trim(),
          location: _locationController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(createClinicControllerProvider, (_, state) {
      if (state.status == SubmitStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultorio registrado.')),
        );
        context.go(kClinicsPath);
      }
    });
    final state = ref.watch(createClinicControllerProvider);
    final enabled = !state.isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kClinicsPath),
        ),
        title: const Text('Nuevo consultorio'),
      ),
      body: CenteredContent(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: enabled,
                maxLength: _maxNameLength,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nombre o número'),
                validator: (v) =>
                    _required(v, 'Ingresá el nombre o número del consultorio.'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                enabled: enabled,
                maxLength: _maxLocationLength,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Ubicación (piso o sector)',
                ),
                validator: (v) => _required(v, 'Ingresá la ubicación.'),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: enabled ? _submit : null,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar consultorio'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: enabled ? () => context.go(kClinicsPath) : null,
                child: const Text('Cancelar'),
              ),
              if (state.status == SubmitStatus.error) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage ?? '',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
