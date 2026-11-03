import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeClinicSearchRepository repository;

  setUp(() {
    final db = FakeAdminDatabase();
    // Prepara solamente esta instancia de prueba, sin cambiar la semilla común.
    db.clinics
      ..clear()
      ..addAll(const [
        Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2, ala norte'),
        Clinic(id: 6, name: 'Consultorio 6', location: 'Piso 2, ala sur'),
        Clinic(id: 12, name: 'Consultorio 12', location: 'Planta baja'),
      ]);
    repository = FakeClinicSearchRepository(db, latency: Duration.zero);
  });

  test('sin filtros ordena por nombre', () async {
    final items = await repository.search(const ClinicFilters());

    expect(items.map((item) => item.name), [
      'Consultorio 12',
      'Consultorio 5',
      'Consultorio 6',
    ]);
  });

  test('consultorio 1 devuelve solo Consultorio 12', () async {
    final items = await repository.search(
      const ClinicFilters(name: 'consultorio 1'),
    );

    expect(items.map((item) => item.name), ['Consultorio 12']);
  });

  test('el nombre 5 devuelve Consultorio 5', () async {
    final items = await repository.search(const ClinicFilters(name: '5'));

    expect(items.map((item) => item.name), ['Consultorio 5']);
  });

  test('PISO 2 devuelve Consultorio 5 y Consultorio 6', () async {
    final items = await repository.search(
      const ClinicFilters(location: 'PISO 2'),
    );

    expect(items.map((item) => item.name), [
      'Consultorio 5',
      'Consultorio 6',
    ]);
  });

  test('orden ubicacion pone Piso 2 antes que Planta baja', () async {
    final items = await repository.search(
      const ClinicFilters(order: ClinicOrder.location),
    );

    // La segunda letra decide: i va antes que l.
    expect(items.map((item) => item.location), [
      'Piso 2, ala norte',
      'Piso 2, ala sur',
      'Planta baja',
    ]);
  });

  test('un nombre de 121 caracteres lanza VALIDACION', () async {
    final filters = ClinicFilters(name: List.filled(121, 'a').join());

    await expectLater(
      repository.search(filters),
      throwsA(
        isA<ClinicSearchException>().having(
          (error) => error.failure,
          'tipo correspondiente a VALIDACION',
          ClinicSearchFailure.validation,
        ),
      ),
    );
  });

  test('una ubicación de 201 caracteres lanza VALIDACION', () async {
    final filters = ClinicFilters(location: List.filled(201, 'b').join());

    await expectLater(
      repository.search(filters),
      throwsA(
        isA<ClinicSearchException>().having(
          (error) => error.failure,
          'tipo correspondiente a VALIDACION',
          ClinicSearchFailure.validation,
        ),
      ),
    );
  });
}
