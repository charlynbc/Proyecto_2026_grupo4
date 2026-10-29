import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_medical_history_repository.dart';
import '../repositories/fake_medical_history_repository.dart';
import '../repositories/medical_history_repository.dart';

/// Selecciona el repositorio falso o la API con el Dio compartido.
final medicalHistoryRepositoryProvider =
    FutureProvider<MedicalHistoryRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeMedicalHistoryRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiMedicalHistoryRepository(dio);
    });
