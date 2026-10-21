/// Un número de un turno: una franja del día con su hora de inicio y de fin,
/// guardadas como minutos desde las 00:00 (hora de Uruguay).
class ShiftNumber {
  const ShiftNumber({
    required this.number,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// Lee `{numero, horaInicio, horaFin}` del contrato, con las horas en `HH:mm`.
  factory ShiftNumber.fromJson(Map<String, dynamic> json) => ShiftNumber(
    number: json['numero'] as int,
    startMinutes: parseTime(json['horaInicio'] as String),
    endMinutes: parseTime(json['horaFin'] as String),
  );

  final int number;
  final int startMinutes;
  final int endMinutes;

  int get duration => endMinutes - startMinutes;

  ShiftNumber copyWith({int? number, int? startMinutes, int? endMinutes}) =>
      ShiftNumber(
        number: number ?? this.number,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
      );

  Map<String, dynamic> toJson() => {
    'numero': number,
    'horaInicio': formatTime(startMinutes),
    'horaFin': formatTime(endMinutes),
  };

  /// `"09:30"` → 570. Un formato distinto de `HH:mm` tira `FormatException`.
  static int parseTime(String time) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (match == null) {
      throw FormatException('Hora con formato inesperado', time);
    }
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  /// 570 → `"09:30"`.
  static String formatTime(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }
}
