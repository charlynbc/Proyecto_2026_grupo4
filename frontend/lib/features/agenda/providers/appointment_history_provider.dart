import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
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

/// Ejecuta [refetch] cuando la pantalla que mira a [ref] vuelve a verse.
///
/// El shell mantiene montadas las secciones que ya se visitaron, y la lista y
/// el detalle de una consulta quedan debajo de otras pantallas: mientras no se
/// ven, Riverpod pausa sus suscripciones pero no descarta el provider, y el
/// estado de la consulta puede haber cambiado (la cancela el funcionario o el
/// médico, o se atiende). Al volver a verse (`onResume`) se pide de nuevo;
/// mientras llega lo nuevo, la pantalla sigue mostrando lo anterior, sin
/// parpadeo.
///
/// Riverpod no deja usar la `Ref` dentro de un ciclo de vida: el pedido se
/// difiere un instante.
void refetchWhenVisibleAgain(Ref ref, void Function() refetch) {
  ref.onResume(() {
    Future.microtask(() {
      if (ref.mounted) refetch();
    });
  });
}

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
