import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../models/access_type.dart';
import '../providers/password_recovery_controllers.dart';
import '../repositories/password_recovery_repository.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/credential_fields.dart';

/// Pedir el enlace para elegir una contraseña nueva (RF-05). Muestra siempre
/// el mismo mensaje, exista o no la cuenta (RNF-10). Sigue el diseño del
/// primer ingreso: no hay caso de uso ni mockup propio.
class PasswordRecoveryRequestScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryRequestScreen({
    super.key,
    this.access = AccessType.socio,
  });

  /// Acceso preseleccionado (`?acceso=`).
  final AccessType access;

  @override
  ConsumerState<PasswordRecoveryRequestScreen> createState() =>
      _PasswordRecoveryRequestScreenState();
}

class _PasswordRecoveryRequestScreenState
    extends ConsumerState<PasswordRecoveryRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();
  late AccessType _access;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _access = widget.access;
  }

  @override
  void dispose() {
    _ciController.dispose();
    super.dispose();
  }

  Future<void> _submit(AccessType access) async {
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(passwordRecoveryRequestControllerProvider.notifier)
        .submit(ci: _ciController.text.trim(), access: access);
  }

  @override
  Widget build(BuildContext context) {
    final employeeAvailable = ref.watch(employeeAccessAvailableProvider);
    final access = employeeAvailable ? _access : AccessType.socio;
    final state = ref.watch(passwordRecoveryRequestControllerProvider);
    final loginPath = '/login?acceso=${access.queryValue}';

    if (state.status == PasswordRecoveryStatus.done) {
      return AuthScaffold(
        subtitle: 'Recuperar contraseña',
        children: [
          const AuthNotice(
            title: 'Revisá tu correo',
            messages: [kPasswordRecoveryRequestedMessage],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go(loginPath),
            child: const Text('Volver al ingreso'),
          ),
        ],
      );
    }

    return AuthScaffold(
      subtitle: 'Recuperar contraseña',
      children: [
        Text(
          'Ingresá tu cédula y, si tenés una cuenta, te enviamos por correo un '
          'enlace para elegir una contraseña nueva. El enlace sirve una sola '
          'vez y vale 24 horas.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (employeeAvailable) ...[
                SegmentedButton<AccessType>(
                  segments: const [
                    ButtonSegment(
                      value: AccessType.socio,
                      label: Text('Socio'),
                    ),
                    ButtonSegment(
                      value: AccessType.empleado,
                      label: Text('Empleado'),
                    ),
                  ],
                  selected: {access},
                  onSelectionChanged: state.isLoading
                      ? null
                      : (selection) =>
                            setState(() => _access = selection.first),
                ),
                const SizedBox(height: 16),
              ],
              CiFormField(
                controller: _ciController,
                enabled: !state.isLoading,
                autovalidateMode: _autovalidate,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.isLoading ? null : () => _submit(access),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continuar'),
              ),
              if (state.status == PasswordRecoveryStatus.error) ...[
                const SizedBox(height: 12),
                AuthNotice(
                  title: 'No pudimos enviar tu pedido',
                  messages: [state.errorMessage ?? ''],
                  isError: true,
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: state.isLoading ? null : () => context.go(loginPath),
                child: const Text('Volver al ingreso'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
