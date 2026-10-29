import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/features/turnos/models/doctor_shift.dart';
import 'package:agenda_medica/features/turnos/models/doctor_shift_number.dart';
import 'package:agenda_medica/features/turnos/providers/doctor_shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/doctor_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_doctor_shift_repository.dart';
import 'package:agenda_medica/features/turnos/screens/doctor_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _initializeLocale() async {
  await initializeDateFormatting('es');
}

class _RecordingDoctorShiftRepository implements DoctorShiftRepository {
  final List<DateTime> receivedDates = [];
  int callCount = 0;

  @override
  Future<List<DoctorShift>> getDoctorShifts({required DateTime date}) async {
    final normalized = DateTime(date.year, date.month, date.day);
    receivedDates.add(normalized);
    callCount += 1;
    return [
      DoctorShift(
        id: 101,
        fecha: normalized,
        horaInicio: '09:00:00',
        horaFin: '12:00:00',
        especialidad: const DoctorShiftSpecialty(
          id: 1,
          nombre: 'Cardiología',
          requierePase: false,
        ),
        consultorio: const DoctorShiftConsultorio(
          id: 3,
          nombre: 'Consultorio 3',
          ubicacion: 'Piso 1',
        ),
        estado: 'ACTIVO',
        cantidadNumeros: 10,
        cantidadReservados: 4,
      ),
    ];
  }

  @override
  Future<DoctorShiftNumbersResponse> getDoctorShiftNumbers({
    required int shiftId,
    bool? llegada,
    String? orden,
    String? sentido,
  }) async {
    throw UnimplementedError();
  }
}

class _SequenceDoctorShiftRepository implements DoctorShiftRepository {
  _SequenceDoctorShiftRepository({
    this.failOnFirstCall = false,
    this.failOnSecondCall = false,
    this.emptyOnFirstCall = false,
  });

  final bool failOnFirstCall;
  final bool failOnSecondCall;
  final bool emptyOnFirstCall;
  int _calls = 0;

  @override
  Future<List<DoctorShift>> getDoctorShifts({required DateTime date}) async {
    _calls += 1;
    if (failOnFirstCall && _calls == 1) {
      throw const DoctorShiftValidationException('No pudimos cargar los turnos.');
    }
    if (failOnSecondCall && _calls == 2) {
      throw const DoctorShiftValidationException('No se pudo actualizar.');
    }
    if (emptyOnFirstCall && _calls == 1) {
      return const <DoctorShift>[];
    }
    return [
      DoctorShift(
        id: 101,
        fecha: date,
        horaInicio: '09:00:00',
        horaFin: '12:00:00',
        especialidad: const DoctorShiftSpecialty(
          id: 1,
          nombre: 'Cardiología',
          requierePase: false,
        ),
        consultorio: const DoctorShiftConsultorio(
          id: 3,
          nombre: 'Consultorio 3',
          ubicacion: 'Piso 1',
        ),
        estado: 'ACTIVO',
        cantidadNumeros: 10,
        cantidadReservados: 4,
      ),
      DoctorShift(
        id: 102,
        fecha: date,
        horaInicio: '14:00:00',
        horaFin: '16:00:00',
        especialidad: const DoctorShiftSpecialty(
          id: 2,
          nombre: 'Pediatría',
          requierePase: false,
        ),
        consultorio: const DoctorShiftConsultorio(
          id: 5,
          nombre: 'Consultorio 5',
          ubicacion: 'Piso 2',
        ),
        estado: 'SUSPENDIDO',
        cantidadNumeros: 10,
        cantidadReservados: 4,
      ),
    ];
  }

  @override
  Future<DoctorShiftNumbersResponse> getDoctorShiftNumbers({
    required int shiftId,
    bool? llegada,
    String? orden,
    String? sentido,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _initializeLocale();
  });

  testWidgets('muestra el listado de turnos y marca los suspendidos', (tester) async {
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => FakeDoctorShiftRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: DoctorShiftsScreen(date: DateTime(2026, 10, 28)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Turnos'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.text('Pediatría'), findsOneWidget);
    expect(find.text('SUSPENDIDO'), findsOneWidget);
    expect(find.text('4 de 10'), findsOneWidget);
    expect(find.text('09:00 - 12:00'), findsOneWidget);
  });

  testWidgets('muestra el horario formateado sin segundos para los turnos', (tester) async {
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => _SequenceDoctorShiftRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: DoctorShiftsScreen(date: DateTime(2026, 10, 28)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('09:00 - 12:00'), findsOneWidget);
    expect(find.text('14:00 - 16:00'), findsOneWidget);
    expect(find.text('09:00:00'), findsNothing);
    expect(find.text('12:00:00'), findsNothing);
    expect(find.text('14:00:00'), findsNothing);
    expect(find.text('16:00:00'), findsNothing);
  });

  testWidgets('muestra el estado vacío cuando no hay turnos', (tester) async {
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => _SequenceDoctorShiftRepository(emptyOnFirstCall: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: DoctorShiftsScreen(date: DateTime(2026, 10, 28)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No tenés turnos para esta fecha'), findsOneWidget);
  });

  testWidgets('muestra el error con botón de reintentar si falla la carga', (tester) async {
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => _SequenceDoctorShiftRepository(failOnFirstCall: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: DoctorShiftsScreen(date: DateTime(2026, 10, 28)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar los turnos.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('muestra el aviso discreto al fallar un refresco con datos previos', (tester) async {
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => _SequenceDoctorShiftRepository(failOnSecondCall: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: DoctorShiftsScreen(date: DateTime(2026, 10, 28)),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(find.text('No se pudo actualizar. Se sigue mostrando la última información.'), findsOneWidget);
  });

  testWidgets('cambia la fecha y recarga el provider con la fecha normalizada', (tester) async {
    final repo = _RecordingDoctorShiftRepository();
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => repo,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: DoctorShiftsScreen(date: DateTime(2026, 10, 28, 18, 45)),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('28/10/2026'), findsOneWidget);
    expect(repo.receivedDates, contains(DateTime(2026, 10, 28)));

    final dateButton = find.text('Elegir fecha');
    await tester.tap(dateButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('29'));
    await tester.pumpAndSettle();

    final okLabel = MaterialLocalizations.of(
      tester.element(find.byType(DoctorShiftsScreen)),
    ).okButtonLabel;
    await tester.tap(find.text(okLabel));
    await tester.pumpAndSettle();

    expect(find.text('29/10/2026'), findsOneWidget);
    expect(repo.receivedDates.last, DateTime(2026, 10, 29));
    expect(repo.receivedDates.last.hour, 0);
    expect(repo.receivedDates.last.minute, 0);
    expect(repo.receivedDates.last.second, 0);
  });

  testWidgets('refresca cada 15 segundos y se cancela al desmontar', (tester) async {
    final repo = _RecordingDoctorShiftRepository();
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => repo,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: DoctorShiftsScreen(date: DateTime(2026, 10, 28)),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(repo.callCount, 1);

    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(repo.callCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(repo.callCount, 2);
  });
}
