import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../models/weekly_shift.dart';
import 'shifts_page_provider.dart';
import 'weekly_shift_clinic_repository_provider.dart';
import 'weekly_shift_provider.dart';

/// Cambia el consultorio de una configuración semanal. Al terminar bien
/// invalida el detalle y el listado.
class ChangeWeeklyShiftClinicController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  /// Envía el cambio. Devuelve la configuración resultante, o `null` si falló:
  /// en ese caso [SubmitState.errorMessage] trae el mensaje del servidor.
  Future<WeeklyShift?> submit(
    int weeklyShiftId,
    int clinicId, {
    List<int>? turnoIds,
    bool confirmarConConsultas = false,
  }) async {
    // Con un envío en curso, un segundo toque no manda otro pedido.
    if (state.isLoading) return null;
    final link = ref.keepAlive();
    state = const SubmitState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(
        weeklyShiftClinicRepositoryProvider.future,
      );
      final updated = await repository.changeClinic(
        weeklyShiftId,
        clinicId,
        turnoIds: turnoIds,
        confirmarConConsultas: confirmarConConsultas,
      );
      ref.invalidate(weeklyShiftProvider(weeklyShiftId));
      ref.invalidate(shiftsPageProvider);
      state = const SubmitState(status: SubmitStatus.done);
      return updated;
    } catch (e) {
      state = SubmitState(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
      );
      return null;
    } finally {
      link.close();
    }
  }

  /// Vuelve a reposo, por ejemplo para quitar el aviso de un intento anterior.
  void reset() {
    state = const SubmitState();
  }
}

final changeWeeklyShiftClinicControllerProvider =
    NotifierProvider.autoDispose<
      ChangeWeeklyShiftClinicController,
      SubmitState
    >(ChangeWeeklyShiftClinicController.new);
