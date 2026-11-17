/// Fecha y hora de Uruguay, con offset fijo -03:00 (no hay horario de
/// verano desde 2015, así que no hace falta un paquete de zonas horarias).
class UruguayTime {
  UruguayTime._();

  static const Duration _offset = Duration(hours: -3);

  /// Hoy en Uruguay, como fecha pura (sin hora) en UTC: se usa solo como
  /// clave de comparación/caché, nunca como un instante real, y sumar días
  /// sobre UTC no se corre por el horario de verano del dispositivo. [now]
  /// permite fijar el instante actual en las pruebas.
  static DateTime today({DateTime? now}) {
    final nowInUruguay = (now ?? DateTime.now()).toUtc().add(_offset);
    return DateTime.utc(
      nowInUruguay.year,
      nowInUruguay.month,
      nowInUruguay.day,
    );
  }

  /// Hoy más los `count - 1` días siguientes, en el mismo formato que [today].
  static List<DateTime> nextDays(int count) {
    final start = today();
    return List.generate(count, (i) => start.add(Duration(days: i)));
  }

  /// El inicio de [day] en Uruguay, como ISO 8601 con offset explícito
  /// -03:00, para mandar al backend en `desde`/`hasta`.
  static String startOfDayIso(DateTime day) {
    final year = day.year.toString().padLeft(4, '0');
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '$year-$month-${dayOfMonth}T00:00:00-03:00';
  }

  /// El instante que corresponde a [hour]:[minute] de Uruguay en el día [day]
  /// (una clave de día: se ignora su hora). Es el inverso de [toUruguay].
  static DateTime fromUruguay(DateTime day, int hour, int minute) {
    return DateTime.utc(
      day.year,
      day.month,
      day.day,
      hour,
      minute,
    ).subtract(_offset);
  }

  /// Un instante como ISO 8601 con el desfase de Uruguay (`-03:00`), para
  /// mandar al backend: `2027-01-01T00:00:00-03:00`.
  static String toIso(DateTime instant) {
    final t = toUruguay(instant);
    String two(int value) => value.toString().padLeft(2, '0');
    final year = t.year.toString().padLeft(4, '0');
    return '$year-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}-03:00';
  }

  /// Reexpresa un instante (por ejemplo, parseado de una respuesta del
  /// backend) en los campos de hora de Uruguay, para mostrar con `intl`.
  static DateTime toUruguay(DateTime dateTime) {
    return dateTime.toUtc().add(_offset);
  }
}
