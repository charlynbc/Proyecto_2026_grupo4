import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_agenda_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Hoy fijo: 24/10/2026. El catálogo de la app es Medicina General (id 1),
// Cardiología (id 2) y Dermatología (id 3). Los médicos de prueba son Carla
// Méndez (id 1, Medicina General), Esteban Silva (id 2, Cardiología) y
// Florencia Acosta (id 3, Pediatría, que no está en el catálogo). El falso
// suma a Lucía Paz (id 4): Medicina General y Dermatología, sin números.
FakeAgendaRepository _repo() {
  final today = DateTime.utc(2026, 10, 24);
  final admin = FakeAdminDatabase();
  final db = FakeDatabase(today: today, admin: admin);
  return FakeAgendaRepository(
    db,
    admin,
    latency: Duration.zero,
    clock: () => DateTime.utc(2026, 10, 24, 15),
  );
}

void main() {
  group('listDoctors', () {
    test('sin filtro lista a los médicos por apellido y nombre', () async {
      final doctors = await _repo().listDoctors();

      expect(doctors.map((d) => d.id), [1, 4, 2]);
      expect(doctors.map((d) => d.lastName), ['Méndez', 'Paz', 'Silva']);
      expect(doctors.map((d) => d.firstName), ['Carla', 'Lucía', 'Esteban']);
    });

    test('cada médico trae sus especialidades del catálogo', () async {
      final doctors = await _repo().listDoctors();

      expect(doctors[0].specialties.map((s) => s.id), [1]);
      expect(doctors[0].specialties.map((s) => s.name), ['Medicina General']);
      expect(doctors[1].specialties.map((s) => s.id), [1, 3]);
      expect(doctors[1].specialties.map((s) => s.name), [
        'Medicina General',
        'Dermatología',
      ]);
      expect(doctors[2].specialties.map((s) => s.id), [2]);
      expect(doctors[2].specialties.map((s) => s.name), ['Cardiología']);
    });

    test('con especialidadId lista solo a quienes la ejercen', () async {
      final repo = _repo();

      expect((await repo.listDoctors(specialtyId: 1)).map((d) => d.id), [1, 4]);
      expect((await repo.listDoctors(specialtyId: 2)).map((d) => d.id), [2]);
      expect((await repo.listDoctors(specialtyId: 3)).map((d) => d.id), [4]);
      expect(await repo.listDoctors(specialtyId: 99), isEmpty);
    });
  });

  group('disponibilidad con médico', () {
    test('solo con médico lista los números de todas sus especialidades', () async {
      final repo = _repo();

      final numbers = await repo.listAvailability(
        const AvailabilityQuery(doctorId: 1),
      );

      expect(numbers, isNotEmpty);
      expect(numbers.map((n) => n.doctor.id).toSet(), {1});
      expect(numbers.map((n) => n.specialty.id).toSet(), {1});
    });

    test('con médico y su especialidad da lo mismo que solo el médico', () async {
      final repo = _repo();

      final onlyDoctor = await repo.listAvailability(
        const AvailabilityQuery(doctorId: 2),
      );
      final both = await repo.listAvailability(
        const AvailabilityQuery(specialtyId: 2, doctorId: 2),
      );

      expect(both.map((n) => n.numberId), onlyDoctor.map((n) => n.numberId));
      expect(both, isNotEmpty);
    });

    test('con médico y una especialidad sin relación da lista vacía', () async {
      final numbers = await _repo().listAvailability(
        const AvailabilityQuery(specialtyId: 2, doctorId: 1),
      );

      expect(numbers, isEmpty);
    });

    test('un médico sin números libres da lista vacía', () async {
      final numbers = await _repo().listAvailability(
        const AvailabilityQuery(doctorId: 4),
      );

      expect(numbers, isEmpty);
    });
  });
}
