import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_arrival_repository.dart';
import '../repositories/arrival_repository.dart';
import '../repositories/fake_arrival_repository.dart';

/// Punto único de inyección del repositorio de llegadas. Con `USE_FAKES=true`
/// devuelve la implementación en memoria.
final arrivalRepositoryProvider = FutureProvider<ArrivalRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) return FakeArrivalRepository();
  final dio = await ref.watch(dioProvider.future);
  return ApiArrivalRepository(dio);
});
