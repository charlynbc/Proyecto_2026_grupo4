import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_password_change_repository.dart';
import '../repositories/fake_password_change_repository.dart';
import '../repositories/password_change_repository.dart';

final passwordChangeRepositoryProvider =
    FutureProvider<PasswordChangeRepository>((ref) async {
      if (ref.watch(useFakesProvider)) return FakePasswordChangeRepository();
      final dio = await ref.watch(dioProvider.future);
      return ApiPasswordChangeRepository(dio);
    });
