import '../../../agenda/models/agenda_time.dart';

class TimeSlotCell {
  const TimeSlotCell({
    required this.day,
    required this.hour,
    required this.count,
  });
  final int day, hour, count;
  factory TimeSlotCell.fromJson(Map<String, dynamic> json) => TimeSlotCell(
    day: json['diaSemana'] as int,
    hour: json['hora'] as int,
    count: json['cantidad'] as int,
  );
}

class TimeSlotStatistics {
  const TimeSlotStatistics({
    required this.from,
    required this.to,
    required this.cells,
  });
  final DateTime from, to;
  final List<TimeSlotCell> cells;
  factory TimeSlotStatistics.fromJson(Map<String, dynamic> json) =>
      TimeSlotStatistics(
        from: parseApiDate(json['desde'] as String),
        to: parseApiDate(json['hasta'] as String),
        cells: [
          for (final cell in json['celdas'] as List<dynamic>)
            TimeSlotCell.fromJson(cell as Map<String, dynamic>),
        ],
      );
}
