final RegExp _uiTimePattern = RegExp(r'^(\d{2}):(\d{2})$');

/// Si [text] tiene exactamente la forma `HH:mm`, sea o no una hora que
/// existe. No recorta espacios.
bool hasUiTimeFormat(String text) => _uiTimePattern.hasMatch(text);

/// Lo que se le dice a quien escribió una hora que no tiene la forma `HH:mm`
/// o que no existe (24:00, 12:60).
const String kUiTimeBadFormatMessage =
    'Escribí la hora como HH:mm, de 00:00 a 23:59, por ejemplo 18:30.';

/// Lee `HH:mm` estricto, de 24 horas: dos dígitos, dos puntos y dos dígitos,
/// con la hora de 00 a 23 y los minutos de 00 a 59. Devuelve `null` si el
/// texto no cumple.
({int hour, int minute})? parseUiTime(String text) {
  final match = _uiTimePattern.firstMatch(text);
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

/// El error de una hora escrita, o `null` si está bien. Un texto vacío no es
/// un error: es un campo sin completar, y reclamarlo es cosa de quien sabe si
/// la hora es obligatoria.
String? uiTimeError(String text) {
  if (text.isEmpty) return null;
  return parseUiTime(text) == null ? kUiTimeBadFormatMessage : null;
}

/// Una hora como `HH:mm` de 24 horas, con dos dígitos en cada campo.
String formatUiTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
