import 'shift_number.dart';

/// Reglas de RF-13 para los números de un turno. El servidor decide en
/// definitiva; acá se validan para avisar antes de enviar.
const int kMinNumberMinutes = 10;
const int kMaxNumberMinutes = 60;
const int kTimeStepMinutes = 5;

/// Las duraciones que se pueden elegir al generar números seguidos.
const List<int> kDurationOptions = [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60];

/// Los [numbers] ordenados por hora de inicio y, con el mismo inicio, por hora
/// de fin. Devuelve una lista nueva y no renumera.
List<ShiftNumber> sortNumbers(List<ShiftNumber> numbers) =>
    [...numbers]..sort((a, b) {
      final byStart = a.startMinutes.compareTo(b.startMinutes);
      return byStart != 0 ? byStart : a.endMinutes.compareTo(b.endMinutes);
    });

/// La hora de fin más tarde de [numbers], o `null` si no hay ninguno.
int? latestEnd(List<ShiftNumber> numbers) => numbers.isEmpty
    ? null
    : numbers.map((e) => e.endMinutes).reduce((a, b) => a > b ? a : b);

/// Si algún número de [numbers] empieza antes que el anterior. Compara solo el
/// inicio: con el mismo inicio no cuenta, aunque los fines estén al revés.
bool isOutOfOrder(List<ShiftNumber> numbers) {
  for (var i = 1; i < numbers.length; i++) {
    if (numbers[i].startMinutes < numbers[i - 1].startMinutes) return true;
  }
  return false;
}

/// Los problemas de una lista de números, un mensaje por problema. Vacía si
/// todo está bien. Los números se nombran como vienen en [numbers].
List<String> validateNumbers(List<ShiftNumber> numbers) {
  if (numbers.isEmpty) return ['Cargá al menos un número.'];

  final errors = <String>[];
  final validRanges = <ShiftNumber>[];
  for (final number in numbers) {
    if (number.endMinutes <= number.startMinutes) {
      errors.add(
        'En el número ${number.number}, la hora de fin tiene que ser '
        'posterior a la de inicio.',
      );
      continue;
    }
    validRanges.add(number);
    if (number.startMinutes % kTimeStepMinutes != 0 ||
        number.endMinutes % kTimeStepMinutes != 0) {
      errors.add(
        'Las horas del número ${number.number} tienen que ser múltiplos de '
        '5 minutos (por ejemplo 09:05 o 09:10).',
      );
    }
    if (number.duration < kMinNumberMinutes ||
        number.duration > kMaxNumberMinutes) {
      errors.add(
        'El número ${number.number} tiene que durar entre '
        '$kMinNumberMinutes y $kMaxNumberMinutes minutos.',
      );
    }
  }

  // Ordenados por hora, alcanza con comparar cada número con el siguiente.
  final byStart = [...validRanges]
    ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  for (var i = 0; i + 1 < byStart.length; i++) {
    final a = byStart[i];
    final b = byStart[i + 1];
    if (a.endMinutes > b.startMinutes) {
      errors.add(
        'Los números ${a.number} y ${b.number} se solapan '
        '(${_range(a)} y ${_range(b)}).',
      );
    }
  }
  return errors;
}

String _range(ShiftNumber number) =>
    '${ShiftNumber.formatTime(number.startMinutes)}–'
    '${ShiftNumber.formatTime(number.endMinutes)}';

/// Los números seguidos que entran en el rango, y los minutos que sobraron al
/// final porque no alcanzaban para otro número entero.
class GeneratedNumbers {
  const GeneratedNumbers(this.numbers, this.leftoverMinutes);

  final List<ShiftNumber> numbers;
  final int leftoverMinutes;
}

/// Quita de [generated] los números que ya están cargados: los que quedan
/// completos dentro de uno de [existing] (idénticos o contenidos). Los que
/// pisan solo una parte de uno cargado, y los que contienen a uno cargado, se
/// conservan: de esos avisa [validateNumbers]. Devuelve los que quedan, en
/// orden y sin cambios, y cuántos se omitieron.
({List<ShiftNumber> kept, int omitted}) omitCoveredNumbers({
  required List<ShiftNumber> existing,
  required List<ShiftNumber> generated,
}) {
  bool isCovered(ShiftNumber number) => existing.any(
    (other) =>
        other.startMinutes <= number.startMinutes &&
        number.endMinutes <= other.endMinutes,
  );
  final kept = [
    for (final number in generated)
      if (!isCovered(number)) number,
  ];
  return (kept: kept, omitted: generated.length - kept.length);
}

GeneratedNumbers generateConsecutive({
  required int startMinutes,
  required int endMinutes,
  required int durationMinutes,
  required int firstNumber,
}) {
  assert(durationMinutes > 0, 'La duración tiene que ser mayor que cero.');
  final numbers = <ShiftNumber>[];
  var cursor = startMinutes;
  while (cursor + durationMinutes <= endMinutes) {
    numbers.add(
      ShiftNumber(
        number: firstNumber + numbers.length,
        startMinutes: cursor,
        endMinutes: cursor + durationMinutes,
      ),
    );
    cursor += durationMinutes;
  }
  final leftover = endMinutes - cursor;
  return GeneratedNumbers(numbers, leftover < 0 ? 0 : leftover);
}

/// Las fechas entre [start] y [end] (inclusive) que caen en [weekday]
/// (1 = lunes … 7 = domingo, como `DateTime.weekday` y el contrato). Las
/// fechas son claves de día en UTC, como las de `UruguayTime`.
List<DateTime> weekdayDatesOf(DateTime start, DateTime end, int weekday) {
  final dates = <DateTime>[];
  var day = DateTime.utc(start.year, start.month, start.day);
  final last = DateTime.utc(end.year, end.month, end.day);
  while (!day.isAfter(last)) {
    if (day.weekday == weekday) dates.add(day);
    day = DateTime.utc(day.year, day.month, day.day + 1);
  }
  return dates;
}

int countWeekdayDates(DateTime start, DateTime end, int weekday) =>
    weekdayDatesOf(start, end, weekday).length;
