import 'package:flutter/foundation.dart' show ValueGetter;

import '../../auth/models/user_role.dart';
import 'user_account.dart';

/// Campos por los que se puede ordenar el padrón (`orden`, contrato #12).
enum UserOrder {
  lastName('apellido', 'Apellido'),
  createdAt('fechaAlta', 'Fecha de alta');

  const UserOrder(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Filtros, orden y página del listado de usuarios (`FiltroUsuariosDTO`).
class UserFilters {
  const UserFilters({
    this.role,
    this.status,
    this.query = '',
    this.order = UserOrder.lastName,
    this.ascending = true,
    this.page = 0,
    this.size = kDefaultPageSize,
  });

  /// Tamaño de página por defecto del contrato (P-19).
  static const int kDefaultPageSize = 20;

  final UserRole? role;
  final AccountStatus? status;

  /// Texto libre: CI o apellido.
  final String query;
  final UserOrder order;
  final bool ascending;
  final int page;
  final int size;

  /// Los parámetros de consulta de #12. Un filtro vacío no se envía.
  Map<String, Object> toQueryParameters() => {
    'rol': ?role?.apiValue,
    'estado': ?status?.apiValue,
    if (query.trim().isNotEmpty) 'q': query.trim(),
    'orden': order.apiValue,
    'sentido': ascending ? 'asc' : 'desc',
    'page': page,
    'size': size,
  };

  UserFilters copyWith({
    ValueGetter<UserRole?>? role,
    ValueGetter<AccountStatus?>? status,
    String? query,
    UserOrder? order,
    bool? ascending,
    int? page,
  }) => UserFilters(
    role: role != null ? role() : this.role,
    status: status != null ? status() : this.status,
    query: query ?? this.query,
    order: order ?? this.order,
    ascending: ascending ?? this.ascending,
    page: page ?? this.page,
    size: size,
  );

  @override
  bool operator ==(Object other) =>
      other is UserFilters &&
      other.role == role &&
      other.status == status &&
      other.query == query &&
      other.order == order &&
      other.ascending == ascending &&
      other.page == page &&
      other.size == size;

  @override
  int get hashCode =>
      Object.hash(role, status, query, order, ascending, page, size);
}
