import 'package:agenda_medica/features/estadisticas/absences/repositories/absence_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/fake_absence_statistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakeAbsenceStatisticsRepository _fake() => FakeAbsenceStatisticsRepository(
  latency: Duration.zero,
  clock: () => DateTime.utc(2026, 10, 14, 15),
);

void main() {
  test('por especialidad devuelve el mes y seis grupos sin apellido', () async {
    final result = await _fake().statistics(
      grouping: AbsenceGrouping.specialty,
    );

    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.groupedBy, 'ESPECIALIDAD');
    expect(result.items, hasLength(6));
    expect(result.items.map((item) => item.name), [
      'Traumatología',
      'Oftalmología',
      'Cardiología',
      'Dermatología',
      'Medicina General',
      'Pediatría',
    ]);
    expect(result.items.map((item) => item.lastName), List.filled(6, null));
    expect(result.items.map((item) => item.id), [6, 5, 3, 4, 1, 2]);
    expect(result.items.map((item) => item.attended), [10, 9, 20, 20, 28, 8]);
    expect(result.items.map((item) => item.noShow), [6, 3, 2, 1, 1, 0]);
    expect(result.items.map((item) => item.missed), [2, 1, 1, 1, 0, 0]);
    expect(result.items.map((item) => item.notAttended), [2, 3, 2, 3, 4, 2]);
    expect(result.items.map((item) => item.total), [20, 16, 25, 25, 33, 10]);
    expect(result.items.map((item) => item.percentage), [
      40.0,
      25.0,
      12.0,
      8.0,
      3.0,
      0.0,
    ]);
    expect(result.items.map((item) => item.percentageText), [
      '40 %',
      '25 %',
      '12 %',
      '8 %',
      '3 %',
      '0 %',
    ]);
  });

  test('por médico devuelve doce grupos, con apellido', () async {
    final result = await _fake().statistics(grouping: AbsenceGrouping.doctor);

    expect(result.groupedBy, 'MEDICO');
    expect(result.items, hasLength(12));
    expect(result.items.map((item) => item.id), [
      9,
      4,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      8,
      18,
    ]);
    expect(result.items.map((item) => item.name), [
      'María Fernanda',
      'Carla',
      'Juan Sebastián',
      'Ana Paula',
      'Gonzalo',
      'Valentina',
      'Rodrigo',
      'Federico',
      'Mariana',
      'Santiago',
      'Luis',
      'Lucía Fernanda',
    ]);
    expect(result.items.map((item) => item.lastName), [
      'Rodríguez Altamirano',
      'Méndez',
      'Fernández Etcheverry',
      'Villalba Cuadrado',
      'Pereira',
      'Techera Hernández',
      'Ferreira',
      'Olivera',
      'Sánchez Larrañaga',
      'Díaz',
      'Gómez',
      'Bermúdez Castellanos',
    ]);
    expect(result.items.map((item) => item.attended), [
      9,
      6,
      12,
      6,
      11,
      10,
      14,
      7,
      24,
      35,
      4,
      12,
    ]);
    expect(result.items.map((item) => item.noShow), [
      7,
      3,
      7,
      3,
      4,
      2,
      2,
      1,
      1,
      1,
      0,
      0,
    ]);
    expect(result.items.map((item) => item.missed), [
      2,
      1,
      2,
      1,
      1,
      1,
      1,
      0,
      1,
      0,
      0,
      0,
    ]);
    expect(result.items.map((item) => item.notAttended), [
      2,
      0,
      4,
      2,
      4,
      3,
      4,
      2,
      4,
      4,
      1,
      1,
    ]);
    expect(result.items.map((item) => item.total), [
      20,
      10,
      25,
      12,
      20,
      16,
      21,
      10,
      30,
      40,
      5,
      13,
    ]);
    expect(result.items.map((item) => item.percentage), [
      45.0,
      40.0,
      36.0,
      33.0,
      25.0,
      18.0,
      14.0,
      10.0,
      6.0,
      2.0,
      0.0,
      0.0,
    ]);
    expect(result.items.map((item) => item.percentageText), [
      '45 %',
      '40 %',
      '36 %',
      '33 %',
      '25 %',
      '18 %',
      '14 %',
      '10 %',
      '6 %',
      '2 %',
      '0 %',
      '0 %',
    ]);
  });

  test(
    'en las dos agrupaciones el orden es de mayor a menor porcentaje',
    () async {
      for (final grouping in AbsenceGrouping.values) {
        final result = await _fake().statistics(grouping: grouping);
        final percentages = result.items
            .map((item) => item.percentage)
            .toList();

        expect(
          percentages,
          orderedEquals([...percentages]..sort((a, b) => b.compareTo(a))),
          reason: grouping.name,
        );
      }
    },
  );

  test('repite las fechas pedidas y no cambia los conteos', () async {
    final result = await _fake().statistics(
      from: DateTime.utc(2026, 9, 5),
      to: DateTime.utc(2026, 9, 20),
      grouping: AbsenceGrouping.specialty,
    );

    expect(result.from, DateTime.utc(2026, 9, 5));
    expect(result.to, DateTime.utc(2026, 9, 20));
    expect(result.items.map((item) => item.total), [20, 16, 25, 25, 33, 10]);
  });

  test('con solo desde completa hasta con el fin del mes en curso', () async {
    final result = await _fake().statistics(
      from: DateTime.utc(2026, 10, 5),
      grouping: AbsenceGrouping.doctor,
    );

    expect(result.from, DateTime.utc(2026, 10, 5));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.groupedBy, 'MEDICO');
  });

  test(
    'un solo día devuelve los grupos de siempre y ninguno con total 0',
    () async {
      final result = await _fake().statistics(
        from: DateTime.utc(2026, 10, 5),
        to: DateTime.utc(2026, 10, 5),
        grouping: AbsenceGrouping.specialty,
      );

      expect(result.from, DateTime.utc(2026, 10, 5));
      expect(result.to, DateTime.utc(2026, 10, 5));
      expect(result.items.map((item) => item.name), [
        'Traumatología',
        'Oftalmología',
        'Cardiología',
        'Dermatología',
        'Medicina General',
        'Pediatría',
      ]);
      expect(result.items.map((item) => item.total), [20, 16, 25, 25, 33, 10]);
    },
  );

  test('con desde posterior a hasta lanza VALIDACION', () async {
    await expectLater(
      _fake().statistics(
        from: DateTime.utc(2026, 10, 20),
        to: DateTime.utc(2026, 10, 5),
        grouping: AbsenceGrouping.specialty,
      ),
      throwsA(
        isA<AbsenceStatisticsException>()
            .having(
              (error) => error.failure,
              'failure',
              AbsenceStatisticsFailure.validation,
            )
            .having(
              (error) => error.message,
              'message',
              'desde no puede ser posterior a hasta',
            ),
      ),
    );
  });
}
