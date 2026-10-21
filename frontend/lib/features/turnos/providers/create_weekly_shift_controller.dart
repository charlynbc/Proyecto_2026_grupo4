import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../models/new_weekly_shift.dart';
import '../models/weekly_shift.dart';
import 'shift_repository_provider.dart';
import 'shifts_page_provider.dart';

/// Alta de un turno semanal (RF-13). Al terminar bien invalida el listado de
/// turnos.
class CreateWeeklyShiftController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  /// Envía el alta. Devuelve el turno semanal creado, o `null` si falló: en
  /// ese caso [SubmitState.errorMessage] trae el mensaje del servidor.
  Future<WeeklyShift?> submit(NewWeeklyShift data) async {
    // Si se sale de la pantalla mientras se envía, el alta igual termina.
    final link = ref.keepAlive();
    state = const SubmitState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(shiftRepositoryProvider.future);
      final created = await repository.createWeeklyShift(data);
      ref.invalidate(shiftsPageProvider);
      state = const SubmitState(status: SubmitStatus.done);
      return created;
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

final createWeeklyShiftControllerProvider =
    NotifierProvider.autoDispose<CreateWeeklyShiftController, SubmitState>(
      CreateWeeklyShiftController.new,
    );
