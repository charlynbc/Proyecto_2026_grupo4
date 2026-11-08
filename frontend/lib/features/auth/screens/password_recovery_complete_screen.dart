import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/password_recovery_controllers.dart';
import '../providers/password_recovery_link_check_provider.dart';
import '../repositories/first_login_repository.dart';
import '../repositories/password_recovery_repository.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/credential_fields.dart';

/// Elegir la contraseña nueva, a la que lleva el enlace del correo
/// (`/recuperacion?token=<token>`). RF-05. No inicia sesión: al terminar vuelve
/// al login con el aviso.
class PasswordRecoveryCompleteScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryCompleteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<PasswordRecoveryCompleteScreen> createState() =>
      _PasswordRecoveryCompleteScreenState();
}

class _PasswordRecoveryCompleteScreenState
    extends ConsumerState<PasswordRecoveryCompleteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Elegí una contraseña.';
    if (password.length < kMinPasswordLength) {
      return 'La contraseña tiene que tener al menos $kMinPasswordLength '
          'caracteres.';
    }
    // El límite del backend es en bytes: una letra con tilde ocupa dos.
    if (utf8.encode(password).length > kMaxPasswordBytes) {
      return 'La contraseña es demasiado larga. Usá una más corta.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'Repetí la contraseña.';
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden. Escribilas de nuevo.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(passwordRecoveryCompleteControllerProvider.notifier)
        .submit(token: widget.token, password: _passwordController.text);
  }

  /// El aviso de enlace inválido, con el mensaje del servidor. Lo usan el
  /// enlace rechazado al abrir y el rechazado al guardar.
  Widget _invalidLinkNotice(
    BuildContext context,
    String message, {
    required String title,
  }) {
    return AuthScaffold(
      subtitle: 'Nueva contraseña',
      children: [
        AuthNotice(title: title, isError: true, messages: [message]),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/recuperacion/solicitar'),
          child: const Text('Pedir un enlace nuevo'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passwordRecoveryCompleteControllerProvider, (_, state) {
      if (state.status == PasswordRecoveryStatus.done) {
        context.go('/login?recuperada=1');
      }
    });
    final state = ref.watch(passwordRecoveryCompleteControllerProvider);
    // Se pregunta una sola vez, al abrir, si el enlace todavía sirve. Solo un
    // enlace que el servidor declara inválido bloquea el formulario.
    final check = ref.watch(passwordRecoveryLinkCheckProvider(widget.token));

    if (state.status == PasswordRecoveryStatus.linkInvalid) {
      return _invalidLinkNotice(
        context,
        state.errorMessage ?? '',
        title: 'No pudimos cambiar tu contraseña',
      );
    }
    if (check.isLoading) {
      return const AuthScaffold(
        subtitle: 'Nueva contraseña',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final invalidMessage = check.value?.invalidMessage;
    if (invalidMessage != null) {
      return _invalidLinkNotice(
        context,
        invalidMessage,
        title: 'Este enlace ya no sirve',
      );
    }

    final enabled = !state.isLoading;
    return AuthScaffold(
      subtitle: 'Nueva contraseña',
      children: [
        Text(
          'Elegí una contraseña nueva para tu cuenta.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordFormField(
                controller: _passwordController,
                label: 'Contraseña nueva',
                hint: 'Mínimo $kMinPasswordLength caracteres',
                validator: _validatePassword,
                enabled: enabled,
                autovalidateMode: _autovalidate,
              ),
              const SizedBox(height: 16),
              PasswordFormField(
                controller: _confirmController,
                label: 'Repetir contraseña',
                validator: _validateConfirm,
                enabled: enabled,
                autovalidateMode: _autovalidate,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: enabled ? _submit : null,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar contraseña'),
              ),
              if (state.status == PasswordRecoveryStatus.error) ...[
                const SizedBox(height: 12),
                AuthNotice(
                  title: 'No pudimos guardar tu contraseña',
                  messages: [state.errorMessage ?? ''],
                  isError: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
