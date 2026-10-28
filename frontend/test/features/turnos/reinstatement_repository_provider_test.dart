import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/features/turnos/providers/reinstatement_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/reinstatement_api_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/reinstatement_fake_repository.dart';
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
  test(
    'con datos falsos el provider devuelve el repositorio en memoria',
    () async {
      final repo = await _container(
        useFakes: true,
      ).read(reinstatementRepositoryProvider.future);
      expect(repo, isA<FakeShiftReinstatementRepository>());
    },
  );

  test('sin datos falsos el provider devuelve la API', () async {
    final repo = await _container(
      useFakes: false,
    ).read(reinstatementRepositoryProvider.future);
    expect(repo, isA<ApiShiftReinstatementRepository>());
  });
}
