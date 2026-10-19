import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_role.dart';
import '../models/role_label.dart';
import '../models/user_account.dart';
import '../models/user_filters.dart';
import '../providers/user_filters_controller.dart';

/// Filtros del padrón (RF-35): CI o apellido, rol y estado se aplican juntos
/// con "Buscar"; el orden se aplica apenas se cambia.
class UsersFilterBar extends ConsumerStatefulWidget {
  const UsersFilterBar({super.key});

  @override
  ConsumerState<UsersFilterBar> createState() => _UsersFilterBarState();
}

class _UsersFilterBarState extends ConsumerState<UsersFilterBar> {
  late final TextEditingController _queryController;
  UserRole? _role;
  AccountStatus? _status;

  @override
  void initState() {
    super.initState();
    final applied = ref.read(userFiltersControllerProvider);
    _queryController = TextEditingController(text: applied.query);
    _role = applied.role;
    _status = applied.status;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search() {
    ref
        .read(userFiltersControllerProvider.notifier)
        .search(role: _role, status: _status, query: _queryController.text);
  }

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(userFiltersControllerProvider);
    final controller = ref.read(userFiltersControllerProvider.notifier);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(labelText: 'CI o apellido'),
            onSubmitted: (_) => _search(),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<UserRole?>(
            initialValue: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final role in UserRole.values)
                DropdownMenuItem(value: role, child: Text(roleLabel(role))),
            ],
            onChanged: (value) => setState(() => _role = value),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<AccountStatus?>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final status in AccountStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) => setState(() => _status = value),
          ),
        ),
        FilledButton.icon(
          onPressed: _search,
          icon: const Icon(Icons.search),
          label: const Text('Buscar'),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<UserOrder>(
            initialValue: applied.order,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ordenar por'),
            items: [
              for (final order in UserOrder.values)
                DropdownMenuItem(value: order, child: Text(order.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              controller.sortBy(value, ascending: applied.ascending);
            },
          ),
        ),
        TextButton.icon(
          onPressed: () =>
              controller.sortBy(applied.order, ascending: !applied.ascending),
          icon: Icon(
            applied.ascending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
          label: Text(applied.ascending ? 'Ascendente' : 'Descendente'),
        ),
      ],
    );
  }
}
