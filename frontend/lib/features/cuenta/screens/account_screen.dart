import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/models/user_role_label.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import 'account_routes.dart';

const String _loadErrorMessage =
    'No pudimos cargar tus datos. Intentá de nuevo.';

/// "Mi cuenta" (`/cuenta`, RF-06 lectura): los datos de la cuenta de quien
/// está logueado. Común a los cuatro roles y fuera de los shells, así que
/// trae su propio Scaffold, sin barra de navegación.
///
/// El cambio de contraseña se abre desde el botón de esta pantalla.
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
    final pendingEmail = account.pendingEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountSection(
          title: 'Datos de la cuenta',
          fields: [
            _Field('Cédula', account.ci, 'account-ci'),
            _Field('Nombre', account.name, 'account-name'),
            _Field('Apellido', account.lastName, 'account-lastname'),
            _Field('Rol', userRoleLabel(account.role), 'account-role'),
          ],
        ),
        const SizedBox(height: 16),
        _AccountSection(
          title: 'Datos de contacto',
          fields: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Field('Correo', account.email, 'account-email'),
                if (pendingEmail != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'El cambio a $pendingEmail está pendiente de '
                      'confirmación. Revisá esa casilla y abrí el enlace. '
                      'Tu correo actual sigue siendo ${account.email}.',
                      key: const Key('account-pending-email'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
            _Field('Teléfono 1', account.phone1, 'account-phone1'),
            _Field(
              'Teléfono 2',
              account.phone2 ?? 'No cargado',
              'account-phone2',
              isMissing: account.phone2 == null,
            ),
            _Field('Dirección', account.address, 'account-address'),
          ],
        ),
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
            OutlinedButton(
              key: const Key('account-password'),
              onPressed: () => context.push(kAccountPasswordPath),
              child: const Text('Cambiar contraseña'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.title, required this.fields});

  final String title;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              fields[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Un dato con su etiqueta arriba. La key va en el valor, que es lo que
/// cambia de una cuenta a otra.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value, this.valueKey, {this.isMissing = false});

  final String label;
  final String value;
  final String valueKey;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              key: Key(valueKey),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isMissing ? FontWeight.normal : FontWeight.w600,
                color: isMissing ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
