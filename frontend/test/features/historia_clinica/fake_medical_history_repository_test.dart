import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeMedicalHistoryRepository repository;

  setUp(() {
    repository = FakeMedicalHistoryRepository(latency: Duration.zero);
  });

  group('datos propios del fake', () {
    test('contiene las cuatro atenciones acordadas', () async {
      final entries = await repository.list(const MedicalHistoryQuery());
      final byId = {for (final entry in entries) entry.id: entry};

      expect(entries, hasLength(4));
      expect(byId.keys, unorderedEquals([10, 11, 12, 13]));

      expect(formatUiDate(byId[10]!.attendedOn), '24/09/2026');
      expect(byId[10]!.doctorFullName, 'Diego Viera');
      expect(byId[10]!.specialty.name, 'Cardiología');
      expect(byId[10]!.condition, 'gripe');
      expect(byId[10]!.treatment, isNull);
      expect(byId[10]!.observations, isNull);
      expect(byId[10]!.referrals, isEmpty);

      expect(formatUiDate(byId[11]!.attendedOn), '10/09/2026');
      expect(byId[11]!.doctorFullName, 'Laura Pérez');
      expect(byId[11]!.specialty.name, 'Traumatología');
      expect(byId[11]!.condition, 'Dolor lumbar');
      expect(byId[11]!.treatment, 'Reposo durante tres días');
      expect(byId[11]!.observations, 'Control de evolución');
      expect(byId[11]!.referrals, isEmpty);

      expect(formatUiDate(byId[12]!.attendedOn), '02/10/2026');
      expect(byId[12]!.doctorFullName, 'Diego Viera');
      expect(byId[12]!.specialty.name, 'Cardiología');
      expect(byId[12]!.condition, 'Control cardiovascular');
      expect(byId[12]!.treatment, 'Reposo relativo y control');
      expect(byId[12]!.observations, 'Continuar seguimiento');

      expect(formatUiDate(byId[13]!.attendedOn), '20/08/2026');
      expect(byId[13]!.doctorFullName, 'Ana Silva');
      expect(byId[13]!.specialty.name, 'Dermatología');
      expect(byId[13]!.condition, 'Reposo mencionado en afección');
      expect(byId[13]!.treatment, 'Crema por la noche');
      expect(byId[13]!.observations, 'Reposo mencionado en observaciones');
      expect(byId[13]!.referrals, isEmpty);
    });

    test('la atención 12 contiene los dos pases acordados', () async {
      final entry = await repository.get(12);

      expect(entry.referrals, hasLength(2));

      final first = entry.referrals[0];
      expect(first.id, 7);
      expect(first.specialty.id, 5);
      expect(first.specialty.name, 'Traumatología');
      expect(first.issuedAt, '2026-10-02T10:00:00-03:00');
      expect(formatUiDate(first.expiresOn), '23/12/2026');

      final second = entry.referrals[1];
      expect(second.id, 8);
      expect(second.specialty.id, 6);
      expect(second.specialty.name, 'Dermatología');
      expect(second.issuedAt, '2026-10-02T10:00:00-03:00');
      expect(formatUiDate(second.expiresOn), '01/11/2026');
    });
  });

  group('filtros', () {
    test('fecha desde incluye las atenciones del mismo día', () async {
      final entries = await repository.list(
        MedicalHistoryQuery(from: DateTime.utc(2026, 9, 24)),
      );

      expect(entries.map((entry) => entry.id), [12, 10]);
    });

    test('fecha hasta incluye las atenciones del mismo día', () async {
      final entries = await repository.list(
        MedicalHistoryQuery(to: DateTime.utc(2026, 9, 10)),
      );

      expect(entries.map((entry) => entry.id), [11, 13]);
    });

    test('combina los dos límites de fecha de forma inclusiva', () async {
      final entries = await repository.list(
        MedicalHistoryQuery(
          from: DateTime.utc(2026, 9, 10),
          to: DateTime.utc(2026, 9, 24),
        ),
      );

      expect(entries.map((entry) => entry.id), [10, 11]);
    });

    test('filtra por especialidad', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(specialtyId: 3),
      );

      expect(entries.map((entry) => entry.id), [12, 10]);
    });

    test('filtra por médico', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(doctorId: 8),
      );

      expect(entries.map((entry) => entry.id), [11]);
    });

    test('busca solo en tratamiento, sin distinguir mayúsculas '
        'y recortando espacios', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(text: '  rEpOsO  '),
      );

      expect(entries.map((entry) => entry.id), [12, 11]);
    });

    test('texto compuesto solo por espacios no filtra', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(text: '   '),
      );

      expect(entries.map((entry) => entry.id), [12, 10, 11, 13]);
    });

    test('combina todos los filtros mediante AND', () async {
      final entries = await repository.list(
        MedicalHistoryQuery(
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 10, 2),
          specialtyId: 3,
          doctorId: 4,
          text: 'reposo',
        ),
      );

      expect(entries.map((entry) => entry.id), [12]);
    });

    test('devuelve vacío si especialidad y médico no coinciden', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(specialtyId: 3, doctorId: 8),
      );

      expect(entries, isEmpty);
    });

    test('una búsqueda sin coincidencias devuelve vacío', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(text: 'antibiótico'),
      );

      expect(entries, isEmpty);
    });
  });

  group('orden', () {
    test('por defecto ordena por fecha descendente', () async {
      final entries = await repository.list(const MedicalHistoryQuery());

      expect(entries.map((entry) => entry.id), [12, 10, 11, 13]);
    });

    test('permite ordenar por fecha ascendente', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(direction: MedicalHistoryDirection.ascending),
      );

      expect(entries.map((entry) => entry.id), [13, 11, 10, 12]);
    });

    // El backend desempata por id_atencion en el mismo sentido del orden.
    test('ordena por especialidad ascendente', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(
          order: MedicalHistoryOrder.specialty,
          direction: MedicalHistoryDirection.ascending,
        ),
      );

      expect(entries.map((entry) => entry.id), [10, 12, 13, 11]);
    });

    test('ordena por especialidad descendente', () async {
      final entries = await repository.list(
        const MedicalHistoryQuery(
          order: MedicalHistoryOrder.specialty,
          direction: MedicalHistoryDirection.descending,
        ),
      );

      expect(entries.map((entry) => entry.id), [11, 13, 12, 10]);
    });
  });

  group('detalle', () {
    test('obtiene por ID una atención aunque antes se haya filtrado', () async {
      await repository.list(const MedicalHistoryQuery(specialtyId: 5));

      final entry = await repository.get(10);

      expect(entry.id, 10);
      expect(entry.doctorFullName, 'Diego Viera');
      expect(entry.condition, 'gripe');
      expect(entry.treatment, isNull);
      expect(entry.observations, isNull);
    });

    test('un ID inexistente produce el error tipado', () async {
      await expectLater(
        repository.get(999),
        throwsA(isA<MedicalHistoryNotFoundException>()),
      );
    });
  });

  test(
    'filtrar y ordenar no altera los datos de consultas posteriores',
    () async {
      await repository.list(
        const MedicalHistoryQuery(
          specialtyId: 5,
          direction: MedicalHistoryDirection.ascending,
        ),
      );
      await repository.list(
        const MedicalHistoryQuery(
          order: MedicalHistoryOrder.specialty,
          direction: MedicalHistoryDirection.ascending,
        ),
      );

      final entries = await repository.list(const MedicalHistoryQuery());

      expect(entries.map((entry) => entry.id), [12, 10, 11, 13]);
    },
  );
}
