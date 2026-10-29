import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_filters_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  MedicalHistoryFiltersController controller() =>
      container.read(medicalHistoryFiltersProvider.notifier);

  MedicalHistoryQuery filters() =>
      container.read(medicalHistoryFiltersProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);

    // Mantiene observado el provider durante cada test.
    container.listen(medicalHistoryFiltersProvider, (_, _) {});
  });

  test('inicia sin filtros y con fecha descendente', () {
    final query = filters();

    expect(query.from, isNull);
    expect(query.to, isNull);
    expect(query.specialtyId, isNull);
    expect(query.doctorId, isNull);
    expect(query.text, isNull);
    expect(query.order, MedicalHistoryOrder.date);
    expect(query.direction, MedicalHistoryDirection.descending);
  });

  test('aplica todos los filtros combinados', () {
    controller().apply(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 10, 2),
      specialtyId: 3,
      doctorId: 4,
      text: 'reposo',
    );

    final query = filters();

    expect(query.from, DateTime.utc(2026, 9, 1));
    expect(query.to, DateTime.utc(2026, 10, 2));
    expect(query.specialtyId, 3);
    expect(query.doctorId, 4);
    expect(query.text, 'reposo');
    expect(query.order, MedicalHistoryOrder.date);
    expect(query.direction, MedicalHistoryDirection.descending);
  });

  test('cambiar filtros conserva el orden y el sentido elegidos', () {
    controller().sortBy(
      MedicalHistoryOrder.specialty,
      direction: MedicalHistoryDirection.ascending,
    );

    controller().apply(
      specialtyId: 5,
      doctorId: 8,
      text: 'control',
    );

    final query = filters();

    expect(query.specialtyId, 5);
    expect(query.doctorId, 8);
    expect(query.text, 'control');
    expect(query.order, MedicalHistoryOrder.specialty);
    expect(query.direction, MedicalHistoryDirection.ascending);
  });

  test('cambiar el orden conserva todos los filtros aplicados', () {
    controller().apply(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 10, 2),
      specialtyId: 3,
      doctorId: 4,
      text: 'reposo',
    );

    controller().sortBy(
      MedicalHistoryOrder.specialty,
      direction: MedicalHistoryDirection.ascending,
    );

    final query = filters();

    expect(query.from, DateTime.utc(2026, 9, 1));
    expect(query.to, DateTime.utc(2026, 10, 2));
    expect(query.specialtyId, 3);
    expect(query.doctorId, 4);
    expect(query.text, 'reposo');
    expect(query.order, MedicalHistoryOrder.specialty);
    expect(query.direction, MedicalHistoryDirection.ascending);
  });

  test('aplicar valores vacíos elimina los filtros anteriores', () {
    controller().apply(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 10, 2),
      specialtyId: 3,
      doctorId: 4,
      text: 'reposo',
    );
    controller().sortBy(
      MedicalHistoryOrder.specialty,
      direction: MedicalHistoryDirection.ascending,
    );

    controller().apply(
      from: null,
      to: null,
      specialtyId: null,
      doctorId: null,
      text: '',
    );

    final query = filters();

    expect(query.from, isNull);
    expect(query.to, isNull);
    expect(query.specialtyId, isNull);
    expect(query.doctorId, isNull);
    expect(query.text ?? '', isEmpty);
    expect(query.order, MedicalHistoryOrder.specialty);
    expect(query.direction, MedicalHistoryDirection.ascending);
  });

  test('limpiar restaura filtros vacíos y fecha descendente', () {
    controller().apply(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 10, 2),
      specialtyId: 3,
      doctorId: 4,
      text: 'reposo',
    );
    controller().sortBy(
      MedicalHistoryOrder.specialty,
      direction: MedicalHistoryDirection.ascending,
    );

    controller().clear();

    final query = filters();

    expect(query.from, isNull);
    expect(query.to, isNull);
    expect(query.specialtyId, isNull);
    expect(query.doctorId, isNull);
    expect(query.text, isNull);
    expect(query.order, MedicalHistoryOrder.date);
    expect(query.direction, MedicalHistoryDirection.descending);
  });
}
