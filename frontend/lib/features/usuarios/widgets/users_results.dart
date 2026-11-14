import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../models/role_label.dart';
import '../models/user_account.dart';
import '../models/user_page.dart';
import '../providers/user_filters_controller.dart';
import '../providers/users_page_provider.dart';
import 'user_actions_menu.dart';

/// Ancho disponible desde el que el padrón se muestra como tabla; con menos,
/// cada cuenta es una tarjeta. La tabla mide 947 px con Roboto y las cuentas
/// del seed de los datos falsos (`columnSpacing: 24`, `horizontalMargin: 16`,
/// con la columna "Acciones"); se suma ~7 % para correos más largos que los
/// del seed. Si la tabla igual no entra, queda el desplazamiento horizontal.
const double kUsersTableMinWidth = 1014;

final DateFormat _uiDate = DateFormat('dd/MM/yyyy');

String _fullName(UserAccount a) => '${a.lastName}, ${a.firstName}';

String _createdOn(UserAccount a) =>
    _uiDate.format(UruguayTime.toUruguay(a.createdAt));

/// La página del padrón: tabla o tarjetas, el aviso de "sin resultados" y el
/// paginador.
class UsersResults extends ConsumerWidget {
  const UsersResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(usersPageProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return page.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pudimos cargar los usuarios. Intentá de nuevo.',
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(usersPageProvider),
            child: const Text('Reintentar'),
          ),
        ],
      ),
      data: (data) => data.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No se encontraron usuarios con esos filtros. Cambiá los '
                'criterios y volvé a buscar.',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Se decide con el ancho que hay de verdad en este lugar (la
                // pantalla menos márgenes y menú), no con el de la ventana.
                LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth >= kUsersTableMinWidth
                      ? _UsersTable(data.items)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final account in data.items)
                              _UserCard(account),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                _Pager(data),
              ],
            ),
    );
  }
}

class _UsersTable extends StatefulWidget {
  const _UsersTable(this.items);

  final List<UserAccount> items;

  @override
  State<_UsersTable> createState() => _UsersTableState();
}

class _UsersTableState extends State<_UsersTable> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La barra se ve siempre (si la tabla no entra) para que se note que se
    // puede desplazar.
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 16,
          columns: const [
            DataColumn(label: Text('CI')),
            DataColumn(label: Text('Apellido y nombre')),
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Correo')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Activada')),
            DataColumn(label: Text('Alta')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: [
            for (final a in widget.items)
              DataRow(
                cells: [
                  DataCell(Text(a.ci)),
                  DataCell(Text(_fullName(a))),
                  DataCell(Text(roleLabel(a.role))),
                  DataCell(Text(a.email)),
                  DataCell(Text(a.status.label)),
                  DataCell(Text(a.activated ? 'Sí' : 'No')),
                  DataCell(Text(_createdOn(a))),
                  DataCell(UserActionsMenu(account: a)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard(this.account);

  final UserAccount account;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fullName(account), style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('CI ${account.ci} · ${roleLabel(account.role)}'),
                  Text(account.email),
                  Text(
                    '${account.status.label} · '
                    'Activada: ${account.activated ? 'Sí' : 'No'} · '
                    'Alta: ${_createdOn(account)}',
                  ),
                ],
              ),
            ),
            UserActionsMenu(account: account),
          ],
        ),
      ),
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager(this.page);

  final UserPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(userFiltersControllerProvider.notifier);
    return PaginationBar(
      label:
          'Página ${page.page + 1} de ${page.pageCount} · '
          '${page.total} ${page.total == 1 ? 'cuenta' : 'cuentas'}',
      hasPrevious: page.hasPrevious,
      hasNext: page.hasNext,
      onPrevious: () => controller.goToPage(page.page - 1),
      onNext: () => controller.goToPage(page.page + 1),
    );
  }
}
