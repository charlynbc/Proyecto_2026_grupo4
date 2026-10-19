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
