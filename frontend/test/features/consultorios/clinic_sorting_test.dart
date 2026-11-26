import 'package:agenda_medica/features/consultorios/clinic_sorting.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _names(List<Clinic> clinics) => [
  for (final clinic in clinics) clinic.name,
];

List<String> _locations(List<Clinic> clinics) => [
  for (final clinic in clinics) clinic.location,
];

void main() {
  const numbered = [
    Clinic(id: 12, name: 'Consultorio 12', location: 'Planta baja'),
    Clinic(id: 3, name: 'Consultorio 3', location: 'Piso 1'),
    Clinic(id: 7, name: 'Consultorio 7', location: 'Piso 2'),
  ];

  test('por nombre ascendente, 3 va antes que 7 y que 12', () {
    final sorted = sortClinics(
      numbered,
      order: ClinicOrder.name,
      ascending: true,
    );

    expect(_names(sorted), [
      'Consultorio 3',
      'Consultorio 7',
      'Consultorio 12',
    ]);
  });

  test('por nombre descendente invierte: 12, 7 y 3', () {
    final sorted = sortClinics(
      numbered,
      order: ClinicOrder.name,
      ascending: false,
    );

    expect(_names(sorted), [
      'Consultorio 12',
      'Consultorio 7',
      'Consultorio 3',
    ]);
  });

  test('por ubicación ascendente: Piso 2, Piso 10 y Planta baja', () {
    const clinics = [
      Clinic(id: 4, name: 'Consultorio 4', location: 'Planta baja'),
      Clinic(id: 8, name: 'Consultorio 8', location: 'Piso 10'),
      Clinic(id: 9, name: 'Consultorio 9', location: 'Piso 2'),
    ];

    final sorted = sortClinics(
      clinics,
      order: ClinicOrder.location,
      ascending: true,
    );

    expect(_locations(sorted), ['Piso 2', 'Piso 10', 'Planta baja']);
  });

  test('por ubicación descendente: Planta baja, Piso 10 y Piso 2', () {
    const clinics = [
      Clinic(id: 4, name: 'Consultorio 4', location: 'Planta baja'),
      Clinic(id: 8, name: 'Consultorio 8', location: 'Piso 10'),
      Clinic(id: 9, name: 'Consultorio 9', location: 'Piso 2'),
    ];

    final sorted = sortClinics(
      clinics,
      order: ClinicOrder.location,
      ascending: false,
    );

    expect(_locations(sorted), ['Planta baja', 'Piso 10', 'Piso 2']);
  });

  test('la ubicación con tilde ordena como sin ella: Ático, Piso 1, Zona', () {
    const clinics = [
      Clinic(id: 9, name: 'Consultorio 9', location: 'Zona'),
      Clinic(id: 8, name: 'Consultorio 8', location: 'Ático'),
      Clinic(id: 4, name: 'Consultorio 4', location: 'Piso 1'),
    ];

    final sorted = sortClinics(
      clinics,
      order: ClinicOrder.location,
      ascending: true,
    );

    expect(_locations(sorted), ['Ático', 'Piso 1', 'Zona']);
  });

  test('con la misma ubicación conserva el orden de llegada y al invertir '
      'lo invierte', () {
    const clinics = [
      Clinic(id: 9, name: 'Consultorio 9', location: 'Piso 2'),
      Clinic(id: 8, name: 'Consultorio 8', location: 'Piso 2'),
    ];

    final ascending = sortClinics(
      clinics,
      order: ClinicOrder.location,
      ascending: true,
    );
    final descending = sortClinics(
      clinics,
      order: ClinicOrder.location,
      ascending: false,
    );

    expect(_names(ascending), ['Consultorio 9', 'Consultorio 8']);
    expect(_names(descending), ['Consultorio 8', 'Consultorio 9']);
  });

  test('devuelve una copia y no toca la lista recibida', () {
    final input = [...numbered];

    sortClinics(input, order: ClinicOrder.name, ascending: false);

    expect(_names(input), ['Consultorio 12', 'Consultorio 3', 'Consultorio 7']);
  });
}
