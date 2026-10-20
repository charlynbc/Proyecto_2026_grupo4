/// Nombres de los días de la semana, en minúscula y en el orden del contrato:
/// el índice 0 es el día 1 (lunes) y el 6 es el día 7 (domingo).
const List<String> kWeekdayNames = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// El nombre de [weekday] (1 a 7), en minúscula.
String weekdayName(int weekday) => kWeekdayNames[weekday - 1];

/// El nombre de [weekday] con la primera letra en mayúscula, para cuando
/// arranca un renglón o una celda.
String weekdayLabel(int weekday) {
  final name = weekdayName(weekday);
  return '${name[0].toUpperCase()}${name.substring(1)}';
}
