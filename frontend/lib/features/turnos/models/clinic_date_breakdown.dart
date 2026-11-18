import '../../consultorios/models/clinic.dart';
import '../../consultorios/natural_order.dart';
import 'shift.dart';
import 'shift_state.dart';

/// Cuántas fechas de hoy en adelante de un turno semanal están en un
/// consultorio, y cuántas de ellas están suspendidas.
class ClinicDateCount {
  const ClinicDateCount({
    required this.clinic,
    required this.dates,
    required this.suspended,
  });

  final Clinic clinic;

  /// Fechas de hoy en adelante en este consultorio (activas y suspendidas).
  final int dates;

  /// De [dates], las que están suspendidas.
  final int suspended;
}

/// El consultorio de cada fecha de un turno semanal, resumido: las fechas de
/// hoy en adelante por consultorio y cuántas fechas ya pasaron.
class ClinicDateBreakdown {
  const ClinicDateBreakdown({required this.upcoming, required this.past});

  /// Por consultorio, en el orden en que aparece cada uno entre las fechas
  /// de hoy en adelante.
  final List<ClinicDateCount> upcoming;

  /// Fechas anteriores a hoy. No cuentan para el aviso de consultorio
  /// variable.
  final int past;

  /// Resume [shifts], que son todas las fechas del turno semanal. [today] es
  /// la clave de día de hoy: la fecha de hoy cuenta como "de hoy en adelante".
  factory ClinicDateBreakdown.from(List<Shift> shifts, DateTime today) {
    var past = 0;
    final clinics = <int, Clinic>{};
    final dates = <int, int>{};
    final suspended = <int, int>{};
    for (final shift in shifts) {
      if (shift.date.isBefore(today)) {
        past++;
        continue;
      }
      final id = shift.clinic.id;
      clinics[id] = shift.clinic;
      dates[id] = (dates[id] ?? 0) + 1;
      if (shift.state == ShiftState.suspended) {
        suspended[id] = (suspended[id] ?? 0) + 1;
      }
    }
    final ids = clinics.keys.toList()
      ..sort((a, b) {
        final byName = compareNatural(clinics[a]!.name, clinics[b]!.name);
        return byName != 0 ? byName : a.compareTo(b);
      });
    return ClinicDateBreakdown(
      upcoming: [
        for (final id in ids)
          ClinicDateCount(
            clinic: clinics[id]!,
            dates: dates[id]!,
            suspended: suspended[id] ?? 0,
          ),
      ],
      past: past,
    );
  }
}
