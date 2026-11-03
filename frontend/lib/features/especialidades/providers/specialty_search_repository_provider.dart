import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_specialty_search_repository.dart';
import '../repositories/fake_specialty_search_repository.dart';
import '../repositories/specialty_search_repository.dart';

/// Selecciona la búsqueda falsa o la API sin alterar el catálogo compartido.
final specialtySearchRepositoryProvider =
    FutureProvider<SpecialtySearchRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeSpecialtySearchRepository(
          ref.watch(fakeAdminDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiSpecialtySearchRepository(dio);
    }, retry: (_, _) => null);
