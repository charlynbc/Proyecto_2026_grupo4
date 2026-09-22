import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reservation.dart';
import 'reservation_repository_provider.dart';

/// autoDispose: la pantalla se visita repetidamente (desde el home, desde el
/// SnackBar de reservar) y tiene que reflejar cancelaciones y reservas
/// nuevas hechas en otra pantalla, no una lista vieja cacheada.
final myReservationsProvider = FutureProvider.autoDispose<List<Reservation>>((
  ref,
) async {
  final repository = await ref.watch(reservationRepositoryProvider.future);
  return repository.listMine();
});
