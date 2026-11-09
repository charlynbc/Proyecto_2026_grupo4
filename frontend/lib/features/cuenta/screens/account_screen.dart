import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/models/user_role.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import 'account_routes.dart';

const String _loadErrorMessage =
    'No pudimos cargar tus datos. Intentá de nuevo.';

/// "Mi cuenta" (`/cuenta`, RF-06 lectura): los datos de la cuenta de quien
/// está logueado. Común a los cuatro roles y fuera de los shells, así que
/// trae su propio Scaffold, sin barra de navegación.
///
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('account-back'),
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          // Después de recargar la página en /cuenta no hay a dónde volver:
          // `/` lleva al inicio del rol.
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Mi cuenta'),
      ),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => CenteredContent(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(_loadErrorMessage),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('account-retry'),
                onPressed: () => ref.invalidate(accountProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (account) => CenteredContent(
          maxWidth: 700,
          child: _AccountDetails(account: account),
        ),
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final pendingEmail = account.pendingEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Datos de la cuenta', style: titleStyle),
        const SizedBox(height: 8),
        _Field('Cédula', account.ci, 'account-ci'),
        _Field('Nombre', account.name, 'account-name'),
        _Field('Apellido', account.lastName, 'account-lastname'),
        _Field('Rol', _roleLabel(account.role), 'account-role'),
        const SizedBox(height: 24),
        Text('Datos de contacto', style: titleStyle),
        const SizedBox(height: 8),
        _Field('Correo', account.email, 'account-email'),
        if (pendingEmail != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Pediste cambiar tu correo a $pendingEmail. Abrí el enlace que '
              'te enviamos a ese correo para confirmarlo. Hasta entonces '
              'seguís usando ${account.email}.',
              key: const Key('account-pending-email'),
            ),
          ),
        _Field('Teléfono 1', account.phone1, 'account-phone1'),
        _Field('Teléfono 2', account.phone2 ?? 'No cargado', 'account-phone2'),
        _Field('Dirección', account.address, 'account-address'),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              key: const Key('account-edit'),
              onPressed: () => context.push(kAccountEditPath),
              child: const Text('Editar mis datos'),
            ),
            const OutlinedButton(
              key: Key('account-password'),
              onPressed: null,
              child: Text('Cambiar contraseña'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Un dato con su etiqueta arriba. La key va en el valor, que es lo que
/// cambia de una cuenta a otra.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value, this.valueKey);

  final String label;
  final String value;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, key: Key(valueKey), style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

String _roleLabel(UserRole role) => switch (role) {
  UserRole.socio => 'Socio',
  UserRole.funcionario => 'Funcionario',
  UserRole.medico => 'Médico',
  UserRole.administrador => 'Administrador',
};
