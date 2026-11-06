import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_first_login_link_repository.dart';
import '../repositories/fake_first_login_link_repository.dart';
import '../repositories/first_login_link_repository.dart';

/// Punto único de inyección del validador del enlace de primer ingreso. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final firstLoginLinkRepositoryProvider =
    FutureProvider<FirstLoginLinkRepository>((ref) async {
      if (ref.watch(useFakesProvider)) return FakeFirstLoginLinkRepository();
      final dio = await ref.watch(dioProvider.future);
      return ApiFirstLoginLinkRepository(dio);
    });
