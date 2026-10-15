import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/access_type.dart';
import '../providers/login_controller.dart';
import 'auth_scaffold.dart';
import 'credential_fields.dart';

/// Formulario de ingreso del acceso [access]. Valida la cédula en el cliente
/// antes de enviar; cualquier rechazo del servidor se muestra con un único
/// mensaje, sin decir cuál de los dos datos falló.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key, required this.access});

  final AccessType access;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();
  final _passwordController = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _ciController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) =>
      (value ?? '').isEmpty ? 'Ingresá tu contraseña.' : null;

  Future<void> _submit() async {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(loginControllerProvider.notifier)
        .submit(
          ci: _ciController.text.trim(),
          password: _passwordController.text,
          access: widget.access,
        );
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CiFormField(
            controller: _ciController,
            enabled: !loginState.isLoading,
            autovalidateMode: _autovalidate,
          ),
          const SizedBox(height: 16),
          PasswordFormField(
            controller: _passwordController,
            validator: _validatePassword,
            enabled: !loginState.isLoading,
            autovalidateMode: _autovalidate,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: loginState.isLoading ? null : _submit,
            child: loginState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ingresar'),
          ),
          if (loginState.status == LoginStatus.error) ...[
            const SizedBox(height: 12),
            AuthNotice(
              title: 'No pudimos iniciar tu sesión',
              messages: [loginState.errorMessage ?? ''],
              isError: true,
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: loginState.isLoading
                ? null
                : () => context.go(
                    '/primer-ingreso/solicitar'
                    '?acceso=${widget.access.queryValue}',
                  ),
            child: const Text('Es mi primera vez'),
          ),
        ],
      ),
    );
  }
}
