import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../repositories/api_reservation_repository.dart';
import '../repositories/reservation_repository.dart';

final reservationRepositoryProvider = FutureProvider<ReservationRepository>((
  ref,
) async {
  final dio = await ref.watch(dioProvider.future);
  return ApiReservationRepository(dio);
});
