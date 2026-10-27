/// Fechas y horas del contrato de la agenda. `fecha` (`YYYY-MM-DD`) y
/// `horaInicio`/`horaFin` (`HH:mm`) son **locales de Uruguay**: no llevan zona
/// y no se interpretan como UTC ni se desplazan.
library;

/// Anticipación máxima para agendar: la fecha de la consulta no puede estar a
/// más de estos días desde hoy (RF-09).
const int kMaxAdvanceDays = 30;

final RegExp _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _timePattern = RegExp(r'^(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$');

/// `"2026-10-22"` → la clave de día `DateTime.utc(2026, 10, 22)`: solo sirve
/// para comparar y mostrar la fecha, nunca es un instante. Un formato
/// distinto tira `FormatException`.
DateTime parseApiDate(String value) {
  final match = _datePattern.firstMatch(value);
  if (match == null) {
    throw FormatException('Fecha con formato inesperado', value);
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('Fecha inexistente', value);
  }
  return date;
}

/// La clave de día [date] como `YYYY-MM-DD`, para los parámetros de consulta.
String formatApiDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// `"09:30"` (o `"09:30:00"`) → 570 minutos desde las 00:00. Un formato
/// distinto tira `FormatException`.
int parseApiTime(String value) {
  final match = _timePattern.firstMatch(value);
  if (match == null) {
    throw FormatException('Hora con formato inesperado', value);
  }
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) {
    throw FormatException('Hora fuera de rango', value);
  }
  return hours * 60 + minutes;
}

/// 570 → `"09:30"`.
String formatMinutes(int minutes) {
  final hours = (minutes ~/ 60).toString().padLeft(2, '0');
  final mins = (minutes % 60).toString().padLeft(2, '0');
  return '$hours:$mins';
}
