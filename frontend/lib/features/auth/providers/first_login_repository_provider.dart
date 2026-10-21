import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_first_login_repository.dart';
import '../repositories/fake_first_login_repository.dart';
import '../repositories/first_login_repository.dart';

/// Punto único de inyección del repositorio de primer ingreso. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final firstLoginRepositoryProvider = FutureProvider<FirstLoginRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) return FakeFirstLoginRepository();
  final dio = await ref.watch(dioProvider.future);
  return ApiFirstLoginRepository(dio);
});
