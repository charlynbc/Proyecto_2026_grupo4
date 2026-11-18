import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic_date_breakdown.dart';
import '../models/shift.dart';
import '../models/shift_filters.dart';
import 'shift_repository_provider.dart';
import 'suspension_clock_provider.dart';
import 'weekly_shift_provider.dart';

/// Filas por pedido: el máximo del contrato (#15, sección 1.3).
const int _kPageSize = 100;

/// El consultorio de cada fecha del turno semanal [id], resumido.
///
/// El listado de turnos (#15) no filtra por turno semanal: se pide con el
/// médico, la especialidad, el día y la vigencia del patrón, se recorren todas
/// las páginas y se queda con las filas cuyo `turnoSemanalId` es [id]. Incluye
/// las fechas pasadas y las suspendidas.
///
/// Lee el patrón sin suscribirse a él: el desglose se vuelve a pedir solo
/// cuando alguien lo invalida (por ejemplo, tras cambiar el consultorio de
/// algunas fechas).
///
/// Sin reintento automático (`retry` en `null`): el desglose muestra su aviso
/// con "Reintentar" apenas falla.
final clinicDateBreakdownProvider = FutureProvider.autoDispose
    .family<ClinicDateBreakdown, int>((ref, id) async {
      final weeklyShift = await ref.read(weeklyShiftProvider(id).future);
      final repository = await ref.watch(shiftRepositoryProvider.future);
      final today = ref.read(suspensionClockProvider)();
      final shifts = <Shift>[];
      var page = 0;
      while (true) {
        final result = await repository.listShifts(
          ShiftFilters(
            doctorId: weeklyShift.doctor.id,
            specialtyId: weeklyShift.specialty.id,
            weekday: weeklyShift.weekday,
            fromDate: weeklyShift.startDate,
            toDate: weeklyShift.endDate,
            size: _kPageSize,
            page: page,
          ),
        );
        shifts.addAll(result.items.where((shift) => shift.weeklyShiftId == id));
        if (!result.hasNext || result.items.isEmpty) break;
        page++;
      }
      return ClinicDateBreakdown.from(shifts, today);
    }, retry: (_, _) => null);
