import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAdminDatabase db;
  late FakeSpecialtySearchRepository repository;

  setUp(() {
    db = FakeAdminDatabase();
    // Prepara solamente esta instancia de prueba, sin cambiar la semilla común.
    db.specialties
      ..clear()
      ..addAll([
        Specialty(
          id: db.newSpecialtyId(),
          name: 'Pediatría',
          requiresReferral: false,
        ),
        Specialty(
          id: db.newSpecialtyId(),
          name: 'Medicina General',
          requiresReferral: false,
        ),
        Specialty(
          id: db.newSpecialtyId(),
          name: 'Cardiología',
          requiresReferral: true,
        ),
        Specialty(
          id: db.newSpecialtyId(),
          name: 'Dermatología',
          requiresReferral: true,
        ),
      ]);
    repository = FakeSpecialtySearchRepository(db, latency: Duration.zero);
  });

  test('sin filtros devuelve todas las especialidades por nombre ascendente',
      () async {
    final items = await repository.search(const SpecialtyFilters());

    expect(items.map((item) => item.name), [
      'Cardiología',
      'Dermatología',
      'Medicina General',
      'Pediatría',
    ]);
  });

  test('CARDIO encuentra Cardiología sin distinguir mayúsculas', () async {
    final items = await repository.search(
      const SpecialtyFilters(name: 'CARDIO'),
    );

    expect(items.map((item) => item.name), ['Cardiología']);
  });

  test('requiere pase Sí devuelve Cardiología y Dermatología', () async {
    final items = await repository.search(
      const SpecialtyFilters(requiresReferral: true),
    );

    expect(items.map((item) => item.name), ['Cardiología', 'Dermatología']);
    expect(items.map((item) => item.requiresReferral), [true, true]);
  });

  test('combina nombre a y requiere pase No', () async {
    final items = await repository.search(
      const SpecialtyFilters(name: 'a', requiresReferral: false),
    );

    expect(items.map((item) => item.name), ['Medicina General', 'Pediatría']);
    expect(items.map((item) => item.requiresReferral), [false, false]);
  });

  test('fechaAlta conserva el orden de alta de las cuatro especialidades',
      () async {
    final items = await repository.search(
      const SpecialtyFilters(order: SpecialtyOrder.createdAt),
    );

    expect(items.map((item) => item.name), [
      'Pediatría',
      'Medicina General',
      'Cardiología',
      'Dermatología',
    ]);
  });

  test('un nombre de 121 caracteres produce el error tipado de validación',
      () async {
    final filters = SpecialtyFilters(name: List.filled(121, 'a').join());

    await expectLater(
      repository.search(filters),
      throwsA(
        isA<SpecialtySearchException>().having(
          (error) => error.failure,
          'tipo correspondiente a VALIDACION',
          SpecialtySearchFailure.validation,
        ),
      ),
    );
  });

  test('buscar y ordenar no modifica ni reordena la colección original',
      () async {
    final originalCollection = db.specialties;
    final originalEntries = List<Specialty>.of(db.specialties);

    await repository.search(const SpecialtyFilters());
    await repository.search(const SpecialtyFilters(requiresReferral: true));
    await repository.search(
      const SpecialtyFilters(order: SpecialtyOrder.createdAt),
    );

    expect(db.specialties, same(originalCollection));
    expect(db.specialties, hasLength(4));
    expect(db.specialties.map((item) => item.name), [
      'Pediatría',
      'Medicina General',
      'Cardiología',
      'Dermatología',
    ]);
    expect(db.specialties.map((item) => item.requiresReferral), [
      false,
      false,
      true,
      true,
    ]);
    for (var index = 0; index < originalEntries.length; index++) {
      expect(db.specialties[index], same(originalEntries[index]));
    }
  });

  test('requiere pase No filtra y no se interpreta como Todas', () async {
    final items = await repository.search(
      const SpecialtyFilters(requiresReferral: false),
    );

    expect(items, hasLength(2));
    expect(items.map((item) => item.name), ['Medicina General', 'Pediatría']);
    expect(items.map((item) => item.requiresReferral), [false, false]);
  });
}
