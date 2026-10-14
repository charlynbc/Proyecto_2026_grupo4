import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_reservation_repository.dart';
import '../repositories/fake_reservation_repository.dart';
import '../repositories/reservation_repository.dart';

/// Punto único de inyección del repositorio de reservas. Con
/// `USE_FAKES=true` (ver [useFakesProvider]) devuelve la implementación en
/// memoria; si no, la de la API.
final reservationRepositoryProvider = FutureProvider<ReservationRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return FakeReservationRepository(ref.watch(fakeDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiReservationRepository(dio);
});
