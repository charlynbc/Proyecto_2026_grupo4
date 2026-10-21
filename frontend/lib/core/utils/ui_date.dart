import 'package:intl/intl.dart';

final DateFormat _uiDate = DateFormat('dd/MM/yyyy');
final RegExp _uiDatePattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

/// Una clave de día en UTC como `dd/mm/aaaa` (RNF-21).
String formatUiDate(DateTime date) => _uiDate.format(date);

/// Si [text] tiene exactamente la forma `dd/mm/aaaa`, exista o no esa fecha.
/// No recorta espacios. Para saber además si la fecha existe, [parseUiDate].
bool hasUiDateFormat(String text) => _uiDatePattern.hasMatch(text);

/// Lo que se le dice a quien escribió una fecha que no tiene la forma
/// `dd/mm/aaaa`.
const String kUiDateBadFormatMessage =
    'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.';

/// Lo que se le dice a quien escribió `dd/mm/aaaa` con un día que no existe,
/// como el 31/02.
const String kUiDateNonexistentMessage =
    'Esa fecha no existe en el calendario. Revisá el día y el mes.';

/// El error de una fecha escrita, o `null` si está bien. Un texto vacío no es
/// un error: es un campo sin completar, y reclamarlo es cosa de quien sabe si
/// la fecha es obligatoria. No recorta espacios: quien llama pasa el texto ya
/// recortado si le corresponde.
String? uiDateError(String text) {
  if (text.isEmpty) return null;
  if (!hasUiDateFormat(text)) return kUiDateBadFormatMessage;
  if (parseUiDate(text) == null) return kUiDateNonexistentMessage;
  return null;
}

/// Lee `dd/mm/aaaa` estricto: dos dígitos, barra, dos dígitos, barra y cuatro
/// dígitos, sin espacios de más, y que sea un día que existe (el 31/02 no).
/// Devuelve la clave de día en UTC, o `null` si el texto no cumple.
DateTime? parseUiDate(String text) {
  final match = _uiDatePattern.firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  // DateTime desborda las fechas imposibles (31/02 → 03/03): se rechazan.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
