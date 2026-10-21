import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeClinicRepository repository;

  setUp(() {
    repository = FakeClinicRepository(
      FakeAdminDatabase(),
      latency: Duration.zero,
    );
  });

  test('el nombre es único una vez normalizado', () async {
    await expectLater(
      repository.create(name: '  consultorio   7 ', location: 'Piso 3'),
      throwsA(isA<DuplicateClinicException>()),
    );
  });

  test('un consultorio nuevo aparece en el listado, ordenado', () async {
    final created = await repository.create(
      name: 'Consultorio 1',
      location: ' Piso 3 ',
    );
    final list = await repository.list();
    expect(list.first.id, created.id);
    expect(list.first.location, 'Piso 3');
  });
}
