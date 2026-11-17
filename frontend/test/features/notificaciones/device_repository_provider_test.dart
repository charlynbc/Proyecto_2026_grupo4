import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/features/notificaciones/providers/device_repository_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/api_device_repository.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_device_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({required bool useFakes}) {
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(useFakes),
      dioProvider.overrideWith((ref) async => Dio()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('con USE_FAKES el repositorio es el falso', () async {
    final repo = await _container(useFakes: true)
        .read(deviceRepositoryProvider.future);

    expect(repo, isA<FakeDeviceRepository>());
  });

  test('sin USE_FAKES el repositorio es el de la API', () async {
    final repo = await _container(useFakes: false)
        .read(deviceRepositoryProvider.future);

    expect(repo, isA<ApiDeviceRepository>());
  });
}
