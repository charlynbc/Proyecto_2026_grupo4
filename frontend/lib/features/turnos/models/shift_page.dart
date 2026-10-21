import 'shift.dart';

/// Una página del listado de turnos (`Page<TurnoDTO>`, contrato 1.3). `total`
/// es la cantidad de fechas que cumplen los filtros, no la de esta página.
class ShiftPage {
  const ShiftPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  factory ShiftPage.fromJson(Map<String, dynamic> json) => ShiftPage(
    items: [
      for (final item in json['items'] as List<dynamic>)
        Shift.fromJson(item as Map<String, dynamic>),
    ],
    page: json['page'] as int,
    size: json['size'] as int,
    total: json['total'] as int,
  );

  final List<Shift> items;

  /// Número de página, desde 0.
  final int page;
  final int size;
  final int total;

  int get pageCount => total == 0 ? 1 : (total + size - 1) ~/ size;

  bool get hasPrevious => page > 0;

  bool get hasNext => page + 1 < pageCount;
}
