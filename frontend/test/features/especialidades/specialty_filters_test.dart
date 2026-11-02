import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpecialtyFilters.toQueryParameters', () {
    test('los filtros predeterminados no envían parámetros', () {
      const filters = SpecialtyFilters();

      expect(filters.toQueryParameters(), <String, dynamic>{});
    });

    test('recorta el nombre antes de enviarlo', () {
      const filters = SpecialtyFilters(name: '  cardio  ');

      expect(filters.toQueryParameters(), {'nombre': 'cardio'});
    });

    test('omite el nombre vacío', () {
      const filters = SpecialtyFilters(name: '');

      expect(filters.toQueryParameters(), <String, dynamic>{});
    });

    test('omite el nombre compuesto solo por espacios', () {
      const filters = SpecialtyFilters(name: '   ');

      expect(filters.toQueryParameters(), <String, dynamic>{});
    });

    test('Todas no envía requierePase', () {
      const filters = SpecialtyFilters(requiresReferral: null);

      expect(filters.toQueryParameters(), <String, dynamic>{});
    });

    test('Sí envía únicamente requierePase true', () {
      const filters = SpecialtyFilters(requiresReferral: true);

      expect(filters.toQueryParameters(), {'requierePase': true});
    });

    test('No envía únicamente requierePase false', () {
      const filters = SpecialtyFilters(requiresReferral: false);

      expect(filters.toQueryParameters(), {'requierePase': false});
    });

    test('omite el orden por nombre elegido explícitamente', () {
      const filters = SpecialtyFilters(order: SpecialtyOrder.name);

      expect(filters.toQueryParameters(), <String, dynamic>{});
    });

    test('envía fechaAlta al ordenar por fecha de alta', () {
      const filters = SpecialtyFilters(order: SpecialtyOrder.createdAt);

      expect(filters.toQueryParameters(), {'orden': 'fechaAlta'});
    });

    test('combina exactamente los tres parámetros del ejemplo de Trello', () {
      const filters = SpecialtyFilters(
        name: 'cardio',
        requiresReferral: true,
        order: SpecialtyOrder.createdAt,
      );

      expect(filters.toQueryParameters(), {
        'nombre': 'cardio',
        'requierePase': true,
        'orden': 'fechaAlta',
      });
    });

    test('acepta un nombre de exactamente 120 caracteres sin truncarlo', () {
      final name = List.filled(120, 'a').join();
      final filters = SpecialtyFilters(name: name);

      expect(filters.toQueryParameters(), {'nombre': name});
    });

    test('rechaza un nombre de 121 caracteres al serializar', () {
      final filters = SpecialtyFilters(name: List.filled(121, 'a').join());

      expect(() => filters.toQueryParameters(), throwsArgumentError);
    });
  });
}
