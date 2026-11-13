import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../historia_clinica/models/medical_history_entry.dart';
import '../repositories/api_doctor_patient_history_repository.dart';
import '../repositories/doctor_patient_history_repository.dart';
import '../repositories/fake_doctor_patient_history_repository.dart';

final doctorPatientHistoryRepositoryProvider =
    FutureProvider<DoctorPatientHistoryRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeDoctorPatientHistoryRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiDoctorPatientHistoryRepository(dio);
    });

final doctorPatientHistoryProvider = FutureProvider.autoDispose
    .family<List<MedicalHistoryEntry>, int>((ref, socioId) async {
      final repository = await ref.watch(
        doctorPatientHistoryRepositoryProvider.future,
      );
      return repository.history(socioId);
    }, retry: (_, _) => null);
