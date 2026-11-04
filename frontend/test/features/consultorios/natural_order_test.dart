import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/natural_order.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_filters_controller.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Devuelve la lista tal como llegó, sin reordenarla.
class _Arrival implements ClinicSearchRepository {
  _Arrival(this.items);

  final List<Clinic> items;

  @override
  Future<List<Clinic>> search(ClinicFilters filters) async => items;
}

Clinic _clinic(int id, String name) {
  return Clinic(id: id, name: name, location: 'Planta baja');
}

/// Llegan Consultorio 40, 39, ..., 1. No es el orden natural, a propósito.
List<String> _from40DownTo1() {
  return [for (var number = 40; number >= 1; number--) 'Consultorio $number'];
}

Future<List<String>> _shownNames(
  List<Clinic> clinics, {
  ClinicOrder order = ClinicOrder.name,
  bool ascending = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      clinicSearchRepositoryProvider.overrideWith(
        (ref) async => _Arrival(clinics),
      ),
    ],
  );
  addTearDown(container.dispose);
  final filters = container.read(clinicFiltersControllerProvider.notifier);
  if (order != ClinicOrder.name) filters.sortBy(order);
  if (!ascending) filters.toggleDirection();
  final subscription = container.listen(clinicListProvider, (_, _) {});
  addTearDown(subscription.close);
  await container.read(clinicSearchProvider.future);
  return [
    for (final clinic in container.read(clinicListProvider).requireValue)
      clinic.name,
  ];
}

void main() {
  test('3 va antes que 12', () {
    expect(compareNatural('3', '12'), lessThan(0));
  });

  test('Consultorio 2 va antes que Consultorio 10', () {
    expect(compareNatural('Consultorio 2', 'Consultorio 10'), lessThan(0));
  });

  test('mayusculas y minusculas se tratan igual', () {
    expect(compareNatural('consultorio 3', 'Consultorio 7'), lessThan(0));
    expect(compareNatural('Consultorio 3', 'consultorio 3'), 0);
  });

  test('sin numeros queda el orden alfabetico', () {
    expect(compareNatural('ala norte', 'ala sur'), lessThan(0));
  });

  test('textos iguales conservan el orden de llegada', () {
    final sorted = sortedNaturally([
      'primero',
      'segundo',
      'tercero',
      'cuarto',
    ], (_) => 'Consultorio 2');

    expect(sorted, ['primero', 'segundo', 'tercero', 'cuarto']);
  });

  test('40 con la misma ubicacion conservan el orden de llegada', () async {
    final arrived = _from40DownTo1();
    final clinics = [
      for (var i = 0; i < arrived.length; i++) _clinic(i + 1, arrived[i]),
    ];

    expect(await _shownNames(clinics, order: ClinicOrder.location), arrived);
  });

  // Descendente invierte la lista ya ordenada. Un empate sale en el orden
  // de llegada al revés. Es lo esperado: el servidor desempata por id y
  // el cliente invierte.
  test(
    '40 con la misma ubicacion en Descendente invierten la llegada',
    () async {
      final arrived = _from40DownTo1();
      final clinics = [
        for (var i = 0; i < arrived.length; i++) _clinic(i + 1, arrived[i]),
      ];

      expect(
        await _shownNames(
          clinics,
          order: ClinicOrder.location,
          ascending: false,
        ),
        [for (var number = 1; number <= 40; number++) 'Consultorio $number'],
      );
    },
  );

  test(
    'Consultorio 03 y Consultorio 3 empatan y conservan la llegada',
    () async {
      expect(compareNatural('Consultorio 03', 'Consultorio 3'), 0);
      const arrived = ['Consultorio 03', 'Consultorio 3'];
      expect(sortedNaturally(arrived, (name) => name), arrived);

      final clinics = [
        _clinic(1, 'Consultorio 03'),
        _clinic(2, 'Consultorio 3'),
      ];
      expect(await _shownNames(clinics, ascending: false), [
        'Consultorio 3',
        'Consultorio 03',
      ]);
    },
  );

  test('un numero largo se compara sin excepcion', () {
    expect(
      compareNatural(
        'Consultorio 123456789012345678901234567890',
        'Consultorio 123456789012345678901234567891',
      ),
      lessThan(0),
    );
  });

  test('los textos vacios no lanzan', () {
    expect(compareNatural('', ''), 0);
    expect(compareNatural('', 'a'), lessThan(0));
  });
}
