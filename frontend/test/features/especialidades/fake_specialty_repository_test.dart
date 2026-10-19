import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeSpecialtyRepository repository;

  setUp(() {
    repository = FakeSpecialtyRepository(
      FakeAdminDatabase(),
      latency: Duration.zero,
    );
  });

  test('el nombre es único sin distinguir mayúsculas ni espacios', () async {
    await expectLater(
      repository.create(name: '  cardiología ', requiresReferral: false),
      throwsA(isA<DuplicateSpecialtyException>()),
    );
  });

  test('una especialidad nueva aparece en el listado, ordenada', () async {
    final created = await repository.create(
      name: 'Anestesia',
      requiresReferral: true,
    );
    final list = await repository.list();
    expect(list.first.name, 'Anestesia');
    expect(list.first.id, created.id);
    expect(list.first.requiresReferral, isTrue);
  });
}
