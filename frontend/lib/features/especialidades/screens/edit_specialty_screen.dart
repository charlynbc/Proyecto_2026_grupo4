import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/widgets/centered_content.dart';
import '../models/specialty.dart';
import '../providers/correct_specialty_controller.dart';
import '../providers/specialties_provider.dart';
import '../repositories/specialty_correction_repository.dart';
import 'specialties_screen.dart';

/// Corrección del nombre y de la exigencia de pase de una especialidad
/// (RF-38). Busca la especialidad por [id] en el catálogo; un [id] que no es
/// un número válido o que no está se trata como no encontrada.
class EditSpecialtyScreen extends ConsumerWidget {
  const EditSpecialtyScreen({super.key, required this.id});

  final int? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(specialtiesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kSpecialtiesPath),
        ),
        title: const Text('Corregir especialidad'),
      ),
      body: catalog.when(
        // Guardar invalida el catálogo: el formulario no tiene que
        // desaparecer mientras se vuelve a pedir.
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'No pudimos cargar las especialidades. Intentá de nuevo.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(specialtiesProvider),
                  child: const Text('Reintentar'),
                ),
              ),
            ],
          ),
        ),
        data: (items) {
          final specialty = items.where((item) => item.id == id).firstOrNull;
          if (specialty == null) return const _NotFound();
          return CenteredContent(
            child: _EditSpecialtyForm(
              key: ValueKey(specialty.id),
              specialty: specialty,
            ),
          );
        },
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return CenteredContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('No encontramos esa especialidad.'),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('edit-specialty-back'),
            onPressed: () => context.go(kSpecialtiesPath),
            child: const Text('Volver a Especialidades'),
          ),
        ],
      ),
    );
  }
}

class _EditSpecialtyForm extends ConsumerStatefulWidget {
  const _EditSpecialtyForm({super.key, required this.specialty});

  final Specialty specialty;

  @override
  ConsumerState<_EditSpecialtyForm> createState() => _EditSpecialtyFormState();
}

class _EditSpecialtyFormState extends ConsumerState<_EditSpecialtyForm> {
  static const int _maxNameLength = 120;

  final _formKey = GlobalKey<FormState>();

  /// Los datos con que se abrió el formulario: lo que se compara y se manda.
  late final Specialty _original = widget.specialty;
  late final _nameController = TextEditingController(text: _original.name);
  late bool _requiresReferral = _original.requiresReferral;

  bool get _nameChanged => _nameController.text.trim() != _original.name.trim();

  bool get _referralChanged => _requiresReferral != _original.requiresReferral;

  bool get _changed => _nameChanged || _referralChanged;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(correctSpecialtyControllerProvider.notifier)
        .submit(
          _original.id,
          name: _nameChanged ? _nameController.text.trim() : null,
          requiresReferral: _referralChanged ? _requiresReferral : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(correctSpecialtyControllerProvider, (_, state) {
      if (state.status == SubmitStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Especialidad corregida.')),
        );
        context.go(kSpecialtiesPath);
      }
    });
    final state = ref.watch(correctSpecialtyControllerProvider);
    final enabled = !state.isLoading;
    final failed = state.status == SubmitStatus.error;
    final duplicate =
        failed && state.failure == SpecialtyCorrectionFailure.duplicate;
    final formError = failed && !duplicate ? state.errorMessage : null;
    final errorStyle = TextStyle(color: Theme.of(context).colorScheme.error);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (formError != null) ...[
            Text(
              formError,
              key: const Key('edit-specialty-form-error'),
              style: errorStyle,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            key: const Key('edit-specialty-name'),
            controller: _nameController,
            enabled: enabled,
            maxLength: _maxNameLength,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Ingresá el nombre de la especialidad.'
                : null,
            onChanged: (_) => setState(() {}),
            onFieldSubmitted: (_) {
              if (enabled && _changed) _submit();
            },
          ),
          if (duplicate)
            Text(
              state.errorMessage ?? '',
              key: const Key('edit-specialty-error'),
              style: errorStyle,
            ),
          CheckboxListTile(
            key: const Key('edit-specialty-requires-referral'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('¿Requiere pase para agendar?'),
            value: _requiresReferral,
            onChanged: enabled
                ? (value) => setState(() => _requiresReferral = value ?? false)
                : null,
          ),
          Text(
            'El cambio de la exigencia de pase rige para las consultas que se '
            'agenden desde ahora. Las consultas ya agendadas no cambian.',
            key: const Key('edit-specialty-note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('edit-specialty-save'),
            onPressed: enabled && _changed ? _submit : null,
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
            key: const Key('edit-specialty-cancel'),
            onPressed: enabled ? () => context.go(kSpecialtiesPath) : null,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
