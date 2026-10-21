import 'user_account.dart';

/// Una página del padrón (`Page<UsuarioDTO>`, contrato 1.3). `total` es la
/// cantidad de cuentas que cumplen los filtros, no la de esta página.
class UserPage {
  const UserPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  final List<UserAccount> items;

  /// Número de página, desde 0.
  final int page;
  final int size;
  final int total;

  int get pageCount => total == 0 ? 1 : (total + size - 1) ~/ size;

  bool get hasPrevious => page > 0;

  bool get hasNext => page + 1 < pageCount;

  factory UserPage.fromJson(Map<String, dynamic> json) => UserPage(
    items: [
      for (final item in json['items'] as List<dynamic>)
        UserAccount.fromJson(item as Map<String, dynamic>),
    ],
    page: json['page'] as int,
    size: json['size'] as int,
    total: json['total'] as int,
  );
}
