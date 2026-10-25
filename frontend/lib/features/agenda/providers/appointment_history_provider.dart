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

/// La página de consultas que corresponde a [AppointmentHistoryQuery].
///
/// Sin reintento automático (`retry` en `null`): Riverpod 3 reintenta solo
/// hasta 10 veces, con esperas de 0,2 a 6,4 s, y durante ese tiempo la
/// pantalla seguiría mostrando el cargando en vez del aviso con "Reintentar".
final appointmentHistoryProvider =
    FutureProvider.family<AppointmentHistoryPage, AppointmentHistoryQuery>((
      ref,
      query,
    ) async {
      ref.watch(appointmentHistoryRefreshProvider);
      final repository = await ref.watch(
        appointmentHistoryRepositoryProvider.future,
      );
      return repository.list(query);
    }, retry: (_, _) => null);

final appointmentDetailProvider = FutureProvider.family<Appointment, int>((
  ref,
  id,
) async {
  ref.watch(appointmentHistoryRefreshProvider);
  final repository = await ref.watch(
    appointmentHistoryRepositoryProvider.future,
  );
  return repository.get(id);
});
