import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/repositories/first_login_repository.dart';
import '../../auth/repositories/password_recovery_repository.dart';
import '../../auth/widgets/credential_fields.dart';
import '../providers/change_password_controller.dart';
import '../repositories/password_change_repository.dart';
import 'account_routes.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _submitting = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? value) =>
      (value ?? '').isEmpty ? 'Ingresá tu contraseña actual.' : null;

  String? _validateNew(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Elegí una contraseña nueva.';
    if (password.length < kMinPasswordLength) {
      return 'La contraseña tiene que tener al menos 8 caracteres.';
    }
    if (utf8.encode(password).length > kMaxPasswordBytes) {
      return 'La contraseña es demasiado larga. Usá una más corta.';
    }
    return null;
  }

  String? _validateRepeat(String? value) {
    if ((value ?? '').isEmpty) return 'Repetí la contraseña nueva.';
    if (value != _new.text) {
      return 'Las contraseñas no coinciden. Escribilas de nuevo.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_submitting) return;
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final saved = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(currentPassword: _current.text, newPassword: _new.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (saved) {
      final messenger = ScaffoldMessenger.of(context);
      context.canPop() ? context.pop() : context.go(kAccountPath);
      messenger.showSnackBar(
        const SnackBar(
          key: Key('password-changed'),
          content: Text('Tu contraseña se actualizó.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);
    final wrongCurrent =
        state.failure == PasswordChangeFailure.wrongCurrentPassword;
    final generalError =
        state.status == ChangePasswordStatus.error && !wrongCurrent;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(kAccountPath),
        ),
        title: const Text('Cambiar contraseña'),
      ),
      body: CenteredContent(
        maxWidth: 700,
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          onChanged: () {
            if (state.status == ChangePasswordStatus.error) {
              ref.read(changePasswordControllerProvider.notifier).clearError();
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (generalError) ...[
                Text(
                  state.failure == PasswordChangeFailure.validation
                      ? state.message ?? 'Revisá las contraseñas.'
                      : 'No pudimos cambiar tu contraseña. Intentá de nuevo.',
                  key: const Key('password-error'),
                ),
                const SizedBox(height: 16),
              ],
              PasswordFormField(
                key: const Key('password-current'),
                controller: _current,
                label: 'Contraseña actual',
                validator: _validateCurrent,
                enabled: !_submitting,
              ),
              if (wrongCurrent)
                Text(
                  state.message ?? 'La contraseña actual no es correcta.',
                  key: const Key('password-current-error'),
                ),
              const SizedBox(height: 16),
              PasswordFormField(
                key: const Key('password-new'),
                controller: _new,
                label: 'Contraseña nueva',
                validator: _validateNew,
                enabled: !_submitting,
              ),
              const SizedBox(height: 16),
              PasswordFormField(
                key: const Key('password-repeat'),
                controller: _repeat,
                label: 'Repetir contraseña nueva',
                validator: _validateRepeat,
                enabled: !_submitting,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('password-save'),
                onPressed: _submitting ? null : _save,
                child: const Text('Guardar contraseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
