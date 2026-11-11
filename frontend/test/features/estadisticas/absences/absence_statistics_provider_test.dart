import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/features/estadisticas/absences/providers/absence_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/api_absence_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/fake_absence_statistics_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('con USE_FAKES entrega el fake y no arma Dio', () async {
    var dioCalls = 0;
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        dioProvider.overrideWith((ref) async {
          dioCalls++;
          throw StateError('El modo Fake no debe inicializar Dio.');
        }),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      absenceStatisticsRepositoryProvider.future,
    );

    expect(repository, isA<FakeAbsenceStatisticsRepository>());
    expect(dioCalls, 0);
  });

  test('sin USE_FAKES entrega la API', () async {
    final dio = Dio();
    addTearDown(dio.close);
    var dioCalls = 0;
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(false),
        dioProvider.overrideWith((ref) async {
          dioCalls++;
          return dio;
        }),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      absenceStatisticsRepositoryProvider.future,
    );

    expect(repository, isA<ApiAbsenceStatisticsRepository>());
    expect(dioCalls, 1);
  });
}
