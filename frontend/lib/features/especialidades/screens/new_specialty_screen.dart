import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/widgets/centered_content.dart';
import '../providers/create_specialty_controller.dart';
import 'specialties_screen.dart';

/// Alta de una especialidad (RF-29, CU 3.5.1).
class NewSpecialtyScreen extends ConsumerStatefulWidget {
  const NewSpecialtyScreen({super.key});

  @override
  ConsumerState<NewSpecialtyScreen> createState() => _NewSpecialtyScreenState();
}

class _NewSpecialtyScreenState extends ConsumerState<NewSpecialtyScreen> {
  static const int _maxNameLength = 120;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _requiresReferral = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(createSpecialtyControllerProvider.notifier)
        .submit(
          name: _nameController.text.trim(),
          requiresReferral: _requiresReferral,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(createSpecialtyControllerProvider, (_, state) {
      if (state.status == SubmitStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Especialidad registrada.')),
        );
        context.go(kSpecialtiesPath);
      }
    });
    final state = ref.watch(createSpecialtyControllerProvider);
    final enabled = !state.isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kSpecialtiesPath),
        ),
        title: const Text('Nueva especialidad'),
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
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  errorMaxLines: 2,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Ingresá el nombre de la especialidad.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('¿Requiere pase para agendar?'),
                value: _requiresReferral,
                onChanged: enabled
                    ? (value) =>
                          setState(() => _requiresReferral = value ?? false)
                    : null,
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
                    : const Text('Guardar especialidad'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: enabled ? () => context.go(kSpecialtiesPath) : null,
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
