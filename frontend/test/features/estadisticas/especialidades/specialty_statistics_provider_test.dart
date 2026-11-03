import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/providers/specialty_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/repositories/fake_specialty_statistics_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('con USE_FAKES entrega la implementación falsa', () async {
    final container = ProviderContainer(
      overrides: [useFakesProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      specialtyStatisticsRepositoryProvider.future,
    );

    expect(repository, isA<FakeSpecialtyStatisticsRepository>());
  });
}
