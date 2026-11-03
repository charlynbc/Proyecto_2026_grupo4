import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_clinic_search_repository.dart';
import '../repositories/clinic_search_repository.dart';
import '../repositories/fake_clinic_search_repository.dart';

/// Selecciona la búsqueda falsa o la API sin alterar el catálogo compartido.
final clinicSearchRepositoryProvider =
    FutureProvider<ClinicSearchRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeClinicSearchRepository(ref.watch(fakeAdminDatabaseProvider));
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiClinicSearchRepository(dio);
    }, retry: (_, _) => null);
