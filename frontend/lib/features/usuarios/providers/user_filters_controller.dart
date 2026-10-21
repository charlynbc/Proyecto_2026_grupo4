import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_role.dart';
import '../models/user_account.dart';
import '../models/user_filters.dart';

/// Los filtros, el orden y la página que están aplicados al listado de
/// usuarios. Cambiar filtros u orden vuelve a la primera página.
class UserFiltersController extends Notifier<UserFilters> {
  @override
  UserFilters build() => const UserFilters();

  /// "Buscar": aplica rol, estado y texto de una vez.
  void search({UserRole? role, AccountStatus? status, String query = ''}) {
    state = UserFilters(
      role: role,
      status: status,
      query: query.trim(),
      order: state.order,
      ascending: state.ascending,
    );
  }

  void sortBy(UserOrder order, {required bool ascending}) {
    state = state.copyWith(order: order, ascending: ascending, page: 0);
  }

  void goToPage(int page) {
    state = state.copyWith(page: page);
  }
}

final userFiltersControllerProvider =
    NotifierProvider.autoDispose<UserFiltersController, UserFilters>(
      UserFiltersController.new,
    );
