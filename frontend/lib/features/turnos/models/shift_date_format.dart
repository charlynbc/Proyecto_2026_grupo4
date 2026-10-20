import 'package:intl/intl.dart';

final DateFormat _uiDate = DateFormat('dd/MM/yyyy');
final RegExp _uiDatePattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

/// Una clave de día en UTC como `dd/mm/aaaa` (RNF-21).
String formatUiDate(DateTime date) => _uiDate.format(date);

/// Si [text] tiene exactamente la forma `dd/mm/aaaa`, exista o no esa fecha.
/// No recorta espacios. Para saber además si la fecha existe, [parseUiDate].
bool hasUiDateFormat(String text) => _uiDatePattern.hasMatch(text);

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
