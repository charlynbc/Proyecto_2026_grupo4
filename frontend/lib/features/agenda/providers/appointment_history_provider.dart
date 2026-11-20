import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/refetch_when_visible_again.dart';
import '../../../core/fakes/fake_database.dart';
import '../../../core/network/dio_client.dart';
import '../models/appointment.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';
import '../repositories/api_appointment_history_repository.dart';
import '../repositories/appointment_history_repository.dart';
import '../repositories/fake_appointment_history_repository.dart';

class AppointmentHistoryRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final appointmentHistoryRefreshProvider =
    NotifierProvider<AppointmentHistoryRefresh, int>(
      AppointmentHistoryRefresh.new,
    );

final appointmentHistoryRepositoryProvider =
    FutureProvider<AppointmentHistoryRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeAppointmentHistoryRepository(
          ref.watch(fakeDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiAppointmentHistoryRepository(dio);
    });

/// La página de consultas que corresponde a [AppointmentHistoryQuery].
///
/// `autoDispose`: no guarda el resultado cuando nadie lo mira, así que cada
/// vez que se entra a la pantalla se pide de nuevo y se ve el estado actual
/// de las consultas. Los filtros, el orden y la página no viven acá sino en la
/// pantalla, y se conservan. Si la pantalla sigue montada pero fuera de la
/// vista, se vuelve a pedir al volver a verla ([refetchWhenVisibleAgain]); eso
/// mueve el contador de [appointmentHistoryRefreshProvider], que también
/// renueva el detalle y las opciones de los filtros de la pantalla (esas
/// opciones salen de un `ref.listen`, que Riverpod no pausa con la vista y por
/// eso no se entera de que la pantalla volvió).
///
/// Sin reintento automático (`retry` en `null`): Riverpod 3 reintenta solo
/// hasta 10 veces, con esperas de 0,2 a 6,4 s, y durante ese tiempo la
/// pantalla seguiría mostrando el cargando en vez del aviso con "Reintentar".
final appointmentHistoryProvider = FutureProvider.autoDispose
    .family<AppointmentHistoryPage, AppointmentHistoryQuery>((
      ref,
      query,
    ) async {
      ref.watch(appointmentHistoryRefreshProvider);
      refetchWhenVisibleAgain(
        ref,
        () => ref.read(appointmentHistoryRefreshProvider.notifier).refresh(),
      );
      final repository = await ref.watch(
        appointmentHistoryRepositoryProvider.future,
      );
      return repository.list(query);
    }, retry: (_, _) => null);

/// El detalle de la consulta [id]. `autoDispose` y con nuevo pedido al volver
/// a verse, igual que el historial ([appointmentHistoryProvider]).
///
/// Sin reintento automático (`retry` en `null`), por lo mismo que el
/// historial: el aviso con "Reintentar" tiene que verse apenas falla.
final appointmentDetailProvider = FutureProvider.autoDispose
    .family<Appointment, int>((ref, id) async {
      ref.watch(appointmentHistoryRefreshProvider);
      refetchWhenVisibleAgain(ref, ref.invalidateSelf);
      final repository = await ref.watch(
        appointmentHistoryRepositoryProvider.future,
      );
      return repository.get(id);
    }, retry: (_, _) => null);
