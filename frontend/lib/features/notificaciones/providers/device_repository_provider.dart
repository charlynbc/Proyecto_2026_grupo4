import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_device_repository.dart';
import '../repositories/device_repository.dart';
import '../repositories/fake_device_repository.dart';

final deviceRepositoryProvider = FutureProvider<DeviceRepository>((ref) async {
  if (ref.watch(useFakesProvider)) {
    return FakeDeviceRepository();
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiDeviceRepository(dio);
});
