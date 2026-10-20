import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shift_filters.dart';
import '../models/shift_state.dart';

/// Los filtros, el orden y la página que están aplicados al listado de
/// turnos. Cambiar filtros u orden vuelve a la primera página.
class ShiftFiltersController extends Notifier<ShiftFilters> {
  @override
  ShiftFilters build() => const ShiftFilters();

  /// "Buscar": aplica todos los filtros de una vez y conserva el orden.
  void search({
    int? doctorId,
    int? specialtyId,
    int? weekday,
    DateTime? fromDate,
    DateTime? toDate,
    ShiftState? shiftState,
  }) {
    state = ShiftFilters(
      doctorId: doctorId,
      specialtyId: specialtyId,
      weekday: weekday,
      fromDate: fromDate,
      toDate: toDate,
      state: shiftState,
      order: state.order,
      ascending: state.ascending,
    );
  }

  void sortBy(ShiftOrder order, {required bool ascending}) {
    state = state.copyWith(order: order, ascending: ascending, page: 0);
  }

  void goToPage(int page) {
    state = state.copyWith(page: page);
  }
}

final shiftFiltersControllerProvider =
    NotifierProvider.autoDispose<ShiftFiltersController, ShiftFilters>(
      ShiftFiltersController.new,
    );
