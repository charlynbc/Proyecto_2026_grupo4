import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../models/shift.dart';
import '../models/shift_filters.dart';
import '../models/shift_state.dart';
import '../models/suspension_filter.dart';
import 'shift_repository_provider.dart';
import 'suspension_clock_provider.dart';

/// Máximo de fechas que se ofrecen en una búsqueda.
const int kMaxSuspensionCandidates = 500;

/// Tamaño de página que se pide al servidor (el máximo del contrato).
const int _pageSize = 100;

/// Hay más fechas que [kMaxSuspensionCandidates]: no se ofrece una selección
/// parcial, se pide achicar el rango.
class TooManySuspensionCandidatesException extends ApiException {
  const TooManySuspensionCandidatesException()
    : super(
        'Hay más de $kMaxSuspensionCandidates fechas en ese rango. Elegí un '
        'rango más corto y buscá de nuevo.',
      );
}

/// Las fechas activas, de hoy en adelante, que cumplen el filtro (RF-14),
/// ordenadas por fecha. Trae todas las páginas, hasta
/// [kMaxSuspensionCandidates].
///
/// Si al ajustar "desde" a hoy queda posterior a "hasta", no hay nada que
/// ofrecer y no se le pregunta al servidor (lo rechazaría con 400).
///
/// Sin reintento automático, como `shiftsPageProvider`.
final suspensionCandidatesProvider = FutureProvider.autoDispose
    .family<List<Shift>, SuspensionFilter>((ref, filter) async {
      final effective = filter.fromTodayOn(
        ref.watch(suspensionClockProvider)(),
      );
      if (effective.fromDate.isAfter(effective.toDate)) return const [];

      final repository = await ref.watch(shiftRepositoryProvider.future);
      final shifts = <Shift>[];
      for (var page = 0; ; page++) {
        final result = await repository.listShifts(
          ShiftFilters(
            doctorId: effective.doctorId,
            specialtyId: effective.specialtyId,
            fromDate: effective.fromDate,
            toDate: effective.toDate,
            state: ShiftState.active,
            page: page,
            size: _pageSize,
          ),
        );
        if (result.total > kMaxSuspensionCandidates) {
          throw const TooManySuspensionCandidatesException();
        }
        shifts.addAll(result.items);
        if (!result.hasNext) return shifts;
      }
    }, retry: (_, _) => null);
