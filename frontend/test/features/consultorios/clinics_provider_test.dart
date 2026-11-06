import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinics_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Devuelve la lista tal como se la escribimos, sin ordenar.
class _FixedCatalog implements ClinicRepository {
  _FixedCatalog(this.items);

  final List<Clinic> items;

  @override
  Future<List<Clinic>> list() async => items;

  @override
  Future<Clinic> create({required String name, required String location}) {
    throw UnimplementedError();
  }
}

Future<List<String>> _names(List<Clinic> clinics) async {
  final container = ProviderContainer(
    overrides: [
      clinicRepositoryProvider.overrideWith(
        (ref) async => _FixedCatalog(clinics),
      ),
    ],
  );
  addTearDown(container.dispose);
  final listed = await container.read(clinicsProvider.future);
  return [for (final clinic in listed) clinic.name];
}

void main() {
  test('12, 3 y 7 llegan asi y salen 3, 7, 12', () async {
    // Ubicaciones a propósito en otro orden: Ático, Piso 1, Zona sería 12, 7, 3.
    expect(
      await _names(const [
        Clinic(id: 12, name: 'Consultorio 12', location: 'Ático'),
        Clinic(id: 3, name: 'Consultorio 3', location: 'Zona'),
        Clinic(id: 7, name: 'Consultorio 7', location: 'Piso 1'),
      ]),
      ['Consultorio 3', 'Consultorio 7', 'Consultorio 12'],
    );
  });

  test('Zeta, Ángel y Bravo salen Ángel, Bravo, Zeta', () async {
    expect(
      await _names(const [
        Clinic(id: 1, name: 'Zeta', location: 'Piso 9'),
        Clinic(id: 2, name: 'Ángel', location: 'Piso 1'),
        Clinic(id: 3, name: 'Bravo', location: 'Piso 10'),
      ]),
      ['Ángel', 'Bravo', 'Zeta'],
    );
  });
}
