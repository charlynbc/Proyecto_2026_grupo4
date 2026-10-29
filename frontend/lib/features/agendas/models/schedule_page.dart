import 'schedule_entry.dart';

/// Una página de la agenda (`Page<AgendaOperativaDTO>`, contrato 1.3). `total`
/// es la cantidad de consultas que cumplen los filtros, no la de esta página.
class SchedulePage {
  const SchedulePage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  factory SchedulePage.fromJson(Map<String, dynamic> json) => SchedulePage(
    items: [
      for (final item in json['items'] as List<dynamic>)
        ScheduleEntry.fromJson(item as Map<String, dynamic>),
    ],
    page: json['page'] as int,
    size: json['size'] as int,
    total: json['total'] as int,
  );

  final List<ScheduleEntry> items;

  /// Número de página, desde 0.
  final int page;
  final int size;
  final int total;

  int get pageCount => total == 0 ? 1 : (total + size - 1) ~/ size;

  bool get hasPrevious => page > 0;

  bool get hasNext => page + 1 < pageCount;
}
