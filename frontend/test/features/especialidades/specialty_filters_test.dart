import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpecialtyFilters.ascending', () {
    test('el sentido predeterminado es ascendente', () {
      const filters = SpecialtyFilters();

      expect(filters.ascending, isTrue);
    });

    test('permite construir filtros con sentido descendente', () {
      const filters = SpecialtyFilters(ascending: false);

      expect(filters.ascending, isFalse);
    });

    test('copyWith cambia el sentido y conserva los filtros y el orden', () {
      const original = SpecialtyFilters(
        name: 'cardio',
        requiresReferral: false,
        order: SpecialtyOrder.createdAt,
      );

      final descending = original.copyWith(ascending: false);

      expect(descending.ascending, isFalse);
      expect(descending.name, 'cardio');
      expect(descending.requiresReferral, isFalse);
      expect(descending.order, SpecialtyOrder.createdAt);
      expect(original.ascending, isTrue);
      expect(original.name, 'cardio');
      expect(original.requiresReferral, isFalse);
      expect(original.order, SpecialtyOrder.createdAt);

      final ascending = descending.copyWith(ascending: true);

      expect(ascending.ascending, isTrue);
      expect(ascending.name, 'cardio');
      expect(ascending.requiresReferral, isFalse);
      expect(ascending.order, SpecialtyOrder.createdAt);
      expect(descending.ascending, isFalse);
    });

    test('copyWith sin cambios conserva el sentido descendente', () {
      const filters = SpecialtyFilters(ascending: false);

      expect(filters.copyWith().ascending, isFalse);
    });

    test('ambos sentidos sin filtros envían exactamente un mapa vacío', () {
      const ascending = SpecialtyFilters(ascending: true);
      const descending = SpecialtyFilters(ascending: false);

      expect(ascending.toQueryParameters(), <String, dynamic>{});
      expect(descending.toQueryParameters(), <String, dynamic>{});
    });

    test(
      'ambos sentidos con Nombre envían únicamente los filtros aplicados',
      () {
        const ascending = SpecialtyFilters(
          name: '  cardio  ',
          requiresReferral: false,
          order: SpecialtyOrder.name,
          ascending: true,
        );
        final descending = ascending.copyWith(ascending: false);

        expect(ascending.toQueryParameters(), {
          'nombre': 'cardio',
          'requierePase': false,
        });
        expect(descending.toQueryParameters(), {
          'nombre': 'cardio',
          'requierePase': false,
        });
      },
    );

    test('Fecha de alta descendente sin filtros envía únicamente orden', () {
      const filters = SpecialtyFilters(
        order: SpecialtyOrder.createdAt,
        ascending: false,
      );

      expect(filters.toQueryParameters(), {'orden': 'fechaAlta'});
    });

    test(
      'ambos sentidos con Fecha de alta envían solo los tres parámetros',
      () {
        const ascending = SpecialtyFilters(
          name: 'cardio',
          requiresReferral: true,
          order: SpecialtyOrder.createdAt,
          ascending: true,
        );
        final descending = ascending.copyWith(ascending: false);

        expect(ascending.toQueryParameters(), {
          'nombre': 'cardio',
          'requierePase': true,
          'orden': 'fechaAlta',
        });
        expect(descending.toQueryParameters(), {
          'nombre': 'cardio',
          'requierePase': true,
          'orden': 'fechaAlta',
        });
      },
    );
  });

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
