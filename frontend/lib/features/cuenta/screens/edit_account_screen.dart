import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/email_field_rules.dart';
import '../../../core/forms/phone_field_rules.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/centered_content.dart';
import '../models/account.dart';
import '../models/account_changes.dart';
import '../providers/account_provider.dart';
import '../providers/account_repository_provider.dart';
import '../repositories/account_repository.dart';
import 'account_routes.dart';

class EditAccountScreen extends ConsumerWidget {
  const EditAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _returnToAccount(context),
        ),
        title: const Text('Editar mis datos'),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => CenteredContent(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No pudimos cargar tus datos. Intentá de nuevo.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(accountProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (account) => CenteredContent(
          maxWidth: 700,
          child: _EditAccountForm(
            key: ValueKey((account.ci, account.role)),
            account: account,
          ),
        ),
      ),
    );
  }
}

void _returnToAccount(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(kAccountPath);
  }
}

class _EditAccountForm extends ConsumerStatefulWidget {
  const _EditAccountForm({super.key, required this.account});

  final Account account;

  @override
  ConsumerState<_EditAccountForm> createState() => _EditAccountFormState();
}

class _EditAccountFormState extends ConsumerState<_EditAccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final _original = widget.account;
  late final _address = TextEditingController(text: _original.address);
  late final _phone1 = TextEditingController(text: _original.phone1);
  late final _phone2 = TextEditingController(text: _original.phone2 ?? '');
  late final _email = TextEditingController(text: _original.email);
  var _autovalidate = AutovalidateMode.disabled;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _phone1.dispose();
    _phone2.dispose();
    _email.dispose();
    super.dispose();
  }

  AccountChanges get _changes {
    final address = _address.text.trim();
    final phone1 = _phone1.text.trim();
    final phone2 = _phone2.text.trim();
    final email = _email.text.trim();
    return AccountChanges(
      address: address == _original.address.trim() ? null : address,
      phone1: phone1 == _original.phone1.trim() ? null : phone1,
      phone2: phone2 == (_original.phone2?.trim() ?? '')
          ? null
          : (value: phone2.isEmpty ? null : phone2),
      email: email == _original.email.trim() ? null : email,
    );
  }

  String? _validatePhone(String? value, {bool required = false}) {
    final phone = (value ?? '').trim();
    if (required && phone.isEmpty) return 'Ingresá un teléfono.';
    if (phone.length > 30) {
      return 'El teléfono no puede tener más de 30 caracteres.';
    }
    return validateOptionalPhone(phone);
  }

  Future<void> _save() async {
    if (_saving) return;
    final changes = _changes;
    if (changes.isEmpty) return;
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final container = ProviderScope.containerOf(context, listen: false);
    final Account updated;
    try {
      final repository = await ref.read(accountRepositoryProvider.future);
      updated = await repository.update(changes);
    } catch (error) {
      if (!mounted) return;
      final message = apiMessageOf(error);
      setState(() {
        _saving = false;
        _error =
            error is! AccountValidationException &&
                message == kApiGenericMessage
            ? 'No pudimos guardar tus datos. Intentá de nuevo.'
            : message;
      });
      return;
    }
    container.invalidate(accountProvider);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    final pendingEmail = updated.pendingEmail;
    final message =
        pendingEmail != null && pendingEmail != _original.pendingEmail
        ? 'Guardamos tus datos. Para cambiar tu correo, abrí el enlace que te '
              'enviamos a $pendingEmail. Vale 24 horas y, hasta entonces, seguís '
              'usando ${updated.email}.'
        : 'Guardamos tus datos.';
    final messenger = ScaffoldMessenger.of(context);
    _returnToAccount(context);
    messenger.showSnackBar(
      SnackBar(key: const Key('edit-saved'), content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      onChanged: () => setState(() => _error = null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Text(
              error,
              key: const Key('edit-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const Key('edit-address'),
            controller: _address,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Dirección'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Ingresá tu dirección.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('edit-phone1'),
            controller: _phone1,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            inputFormatters: kPhoneInputFormatters,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Teléfono 1',
              errorMaxLines: 4,
            ),
            validator: (value) => _validatePhone(value, required: true),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('edit-phone2'),
            controller: _phone2,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            inputFormatters: kPhoneInputFormatters,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Teléfono 2 (opcional)',
              errorMaxLines: 4,
            ),
            validator: _validatePhone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('edit-email'),
            controller: _email,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo',
              errorMaxLines: 4,
            ),
            validator: validateEmail,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('edit-save'),
            onPressed: _saving || _changes.isEmpty ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
