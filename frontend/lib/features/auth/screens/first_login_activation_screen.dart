import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/first_login_controllers.dart';
import '../providers/first_login_link_check_provider.dart';
import '../repositories/first_login_repository.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/credential_fields.dart';

/// Activación de la cuenta, a la que llega el enlace del correo
/// (`/primer-ingreso?token=...`). RF-02, CU 3.1.2 pasos 9 a 12.
///
/// El correo registrado no se edita (y el contrato no tiene una llamada para
/// leerlo, P-04): se aclara en pantalla pero no se muestra la dirección.
class FirstLoginActivationScreen extends ConsumerStatefulWidget {
  const FirstLoginActivationScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<FirstLoginActivationScreen> createState() =>
      _FirstLoginActivationScreenState();
}

class _FirstLoginActivationScreenState
    extends ConsumerState<FirstLoginActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _addressController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Elegí una contraseña.';
    if (password.length < kMinPasswordLength) {
      return 'La contraseña tiene que tener al menos $kMinPasswordLength '
          'caracteres.';
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
    final phone2 = _phone2Controller.text.trim();
    await ref
        .read(firstLoginActivationControllerProvider.notifier)
        .submit(
          token: widget.token,
          address: _addressController.text.trim(),
          phone1: _phone1Controller.text.trim(),
          phone2: phone2.isEmpty ? null : phone2,
          password: _passwordController.text,
        );
  }

  /// El aviso de enlace inválido, con los textos de siempre. Lo usan el
  /// enlace rechazado al abrir y el rechazado al guardar.
  Widget _invalidLinkNotice(BuildContext context) {
    return AuthScaffold(
      subtitle: 'Primer ingreso',
      children: [
        const AuthNotice(
          title: 'El enlace ya no es válido',
          isError: true,
          messages: [
            'El enlace venció, ya se usó o no se puede usar para activar '
                'esta cuenta. Podés pedir uno nuevo con tu cédula.',
            'Si el problema sigue, comunicate con la institución.',
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/primer-ingreso/solicitar'),
          child: const Text('Pedir un enlace nuevo'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(firstLoginActivationControllerProvider, (_, state) {
      if (state.status == FirstLoginStatus.done) {
        final access = state.access?.queryValue ?? 'socio';
        context.go('/login?acceso=$access&activada=1');
      }
    });
    final state = ref.watch(firstLoginActivationControllerProvider);
    // Se pregunta una sola vez, al abrir, si el enlace todavía sirve. Solo un
    // enlace que el servidor declara inválido bloquea el formulario.
    final check = ref.watch(firstLoginLinkCheckProvider(widget.token));

    if (state.status == FirstLoginStatus.linkInvalid) {
      return _invalidLinkNotice(context);
    }
    if (check.isLoading) {
      return const AuthScaffold(
        subtitle: 'Activá tu cuenta',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    if (check.value?.isInvalid ?? false) {
      return _invalidLinkNotice(context);
    }

    final enabled = !state.isLoading;
    return AuthScaffold(
      subtitle: 'Activá tu cuenta',
      children: [
        Text(
          'Completá tus datos y elegí una contraseña. Vamos a usar el correo '
          'que la institución tiene registrado; no se puede cambiar en este '
          'paso.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _addressController,
                enabled: enabled,
                autovalidateMode: _autovalidate,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) => _required(v, 'Ingresá tu dirección.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone1Controller,
                enabled: enabled,
                autovalidateMode: _autovalidate,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Teléfono 1'),
                validator: (v) => _required(v, 'Ingresá un teléfono.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone2Controller,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Teléfono 2 (opcional)',
                ),
              ),
              const SizedBox(height: 16),
              PasswordFormField(
                controller: _passwordController,
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
                    : const Text('Activar cuenta'),
              ),
              if (state.status == FirstLoginStatus.error) ...[
                const SizedBox(height: 12),
                AuthNotice(
                  title: 'No pudimos activar tu cuenta',
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
