import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validators/uruguayan_ci_validator.dart';
import '../models/access_type.dart';
import '../providers/login_controller.dart';
import 'auth_scaffold.dart';
import 'credential_fields.dart';

/// Formulario de ingreso del acceso [access]. Valida la cédula en el cliente
/// antes de enviar; cualquier rechazo del servidor se muestra con un único
/// mensaje, sin decir cuál de los dos datos falló.
///
/// Los campos se validan mientras se escribe, pero sin molestar: con el foco
/// en el campo, la cédula no marca error hasta tener los 8 dígitos y la
/// contraseña no lo marca mientras está vacía. Al salir del campo, o al
/// apretar "Ingresar", se valida todo.
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
  final _ciFocus = FocusNode();
  final _passwordFocus = FocusNode();

  /// Verdadero solo mientras se valida al enviar: ahí se ignora el foco.
  bool _validatingAll = false;

  @override
  void initState() {
    super.initState();
    // Sin esto no se revalida al perder el foco: el campo solo revalida
    // cuando el formulario se reconstruye.
    _ciFocus.addListener(_onFocusChanged);
    _passwordFocus.addListener(_onFocusChanged);
    // El error de un ingreso fallido es del acceso anterior: se descarta al
    // montar el formulario de otro acceso. Diferido, porque no se puede
    // modificar un provider mientras se construye el árbol.
    Future.microtask(() {
      if (mounted) ref.read(loginControllerProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _ciFocus.dispose();
    _passwordFocus.dispose();
    _ciController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  bool _isTyping(FocusNode node) => node.hasFocus && !_validatingAll;

  String? _validateCi(String? value) {
    final ci = value?.trim() ?? '';
    if (_isTyping(_ciFocus) && ci.length < 8) return null;
    if (ci.isEmpty || !isValidUruguayanCi(ci)) {
      return 'La cédula no es válida. Escribila completa, con el dígito '
          'verificador, sin puntos ni guiones.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (_isTyping(_passwordFocus) && (value ?? '').isEmpty) return null;
    return (value ?? '').isEmpty ? 'Ingresá tu contraseña.' : null;
  }

  Future<void> _submit() async {
    // Sin foco en ningún campo, los errores del envío no se borran al
    // reconstruir el formulario (tocar un botón no siempre suelta el foco).
    FocusScope.of(context).unfocus();
    _validatingAll = true;
    final valid = _formKey.currentState?.validate() ?? false;
    _validatingAll = false;
    if (!valid) return;
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
            focusNode: _ciFocus,
            validator: _validateCi,
            enabled: !loginState.isLoading,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 16),
          PasswordFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            validator: _validatePassword,
            enabled: !loginState.isLoading,
            autovalidateMode: AutovalidateMode.onUserInteraction,
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
