import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_page.dart';
import 'user_filters_controller.dart';
import 'user_repository_provider.dart';

/// La página del padrón que corresponde a los filtros aplicados. Se vuelve a
/// pedir al servidor cada vez que cambian; el alta de un usuario y el cambio
/// de estado de una cuenta la invalidan.
///
/// Si la página pedida quedó fuera de rango (por ejemplo, se inactivó la única
/// cuenta de la última página con el filtro "Activo") pero el servidor dice que
/// hay cuentas en total, se pide la última página que existe con los mismos
/// filtros y el mismo orden. Con total cero no se vuelve a pedir nada.
final usersPageProvider = FutureProvider.autoDispose<UserPage>((ref) async {
  final filters = ref.watch(userFiltersControllerProvider);
  final repository = await ref.watch(userRepositoryProvider.future);
  final page = await repository.listUsers(filters);
  if (page.items.isEmpty && page.total > 0 && filters.page > 0) {
    final last = page.pageCount - 1;
    if (last < filters.page) {
      return repository.listUsers(filters.copyWith(page: last));
    }
  }
  return page;
});
