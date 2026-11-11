import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_doctor_attention_repository.dart';
import '../repositories/doctor_attention_repository.dart';
import '../repositories/fake_doctor_attention_repository.dart';

final doctorAttentionRepositoryProvider =
    FutureProvider<DoctorAttentionRepository>((ref) async {
      if (ref.watch(useFakesProvider)) return FakeDoctorAttentionRepository();
      return ApiDoctorAttentionRepository(await ref.watch(dioProvider.future));
    });
