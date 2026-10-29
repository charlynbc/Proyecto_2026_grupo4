import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/features/turnos/models/doctor_shift.dart';
import 'package:agenda_medica/features/turnos/models/doctor_shift_number.dart';
import 'package:agenda_medica/features/turnos/providers/doctor_shift_numbers_provider.dart';
import 'package:agenda_medica/features/turnos/providers/doctor_shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/doctor_shift_repository.dart';
import 'package:agenda_medica/features/turnos/screens/doctor_shift_numbers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _initializeLocale() async {
  await initializeDateFormatting('es');
}

class _RecordingDoctorShiftNumbersRepository implements DoctorShiftRepository {
  _RecordingDoctorShiftNumbersRepository({
    this.failOnSecondCall = false,
    List<DoctorShiftNumber>? items,
  }) : items = items ?? _baseItems;

  final bool failOnSecondCall;
  final List<DoctorShiftNumber> items;
  final List<DoctorShiftNumbersParams> paramsHistory = [];
  int callCount = 0;

  static final List<DoctorShiftNumber> _baseItems = [
    DoctorShiftNumber(
      numeroId: 1,
      numero: 1,
      horaInicio: '09:00',
      horaFin: '09:15',
      consulta: DoctorShiftAppointment(
        id: 9001,
        estado: 'AGENDADA',
        paciente: DoctorShiftPatient(
          ci: '90000030',
          nombre: 'Carlos',
          apellido: 'Rodríguez',
        ),
        llegadaEn: DateTime.utc(2026, 10, 28, 12, 15),
      ),
      disponible: false,
    ),
    DoctorShiftNumber(
      numeroId: 2,
      numero: 2,
      horaInicio: '09:15',
      horaFin: '09:30',
      consulta: null,
      disponible: true,
    ),
    DoctorShiftNumber(
      numeroId: 3,
      numero: 3,
      horaInicio: '09:30',
      horaFin: '09:45',
      consulta: DoctorShiftAppointment(
        id: 9003,
        estado: 'AGENDADA',
        paciente: DoctorShiftPatient(
          ci: '90000050',
          nombre: 'María',
          apellido: 'López',
        ),
        llegadaEn: null,
      ),
      disponible: false,
    ),
    DoctorShiftNumber(
      numeroId: 4,
      numero: 4,
      horaInicio: '09:45',
      horaFin: '10:00',
      consulta: null,
      disponible: false,
    ),
  ];

  @override
  Future<List<DoctorShift>> getDoctorShifts({required DateTime date}) async {
    throw UnimplementedError();
  }

  @override
  Future<DoctorShiftNumbersResponse> getDoctorShiftNumbers({
    required int shiftId,
    bool? llegada,
    String? orden,
    String? sentido,
  }) async {
    callCount += 1;
    final params = DoctorShiftNumbersParams(
      shiftId: shiftId,
      llegada: llegada,
      orden: orden,
      sentido: sentido,
    );
    paramsHistory.add(params);

    if (orden != null && !{'hora', 'horaLlegada'}.contains(orden)) {
      throw const DoctorShiftValidationException('Orden inválido.');
    }
    if (sentido != null && !{'asc', 'desc'}.contains(sentido)) {
      throw const DoctorShiftValidationException('Sentido inválido.');
    }

    if (failOnSecondCall && callCount == 2) {
      throw const DoctorShiftValidationException('No se pudo actualizar.');
    }

    return DoctorShiftNumbersResponse(
      turno: DoctorShiftDetail(
        id: shiftId,
        fecha: DateTime(2026, 10, 28),
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
      ),
      items: items,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _initializeLocale();
  });

  testWidgets('muestra los tres estados de cada número', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Finder findCardForNumber(int numero) {
      return find.byWidgetPredicate((widget) {
        if (widget is! Card) return false;

        final child = widget.child;
        if (child is! Padding) return false;

        final column = child.child;
        if (column is! Column) return false;

        for (final element in column.children) {
          if (element is! Row) continue;

          for (final rowChild in element.children) {
            if (rowChild is! Expanded) continue;

            final content = rowChild.child;
            if (content is Text && content.data == 'N.º $numero') {
              return true;
            }
          }
        }

        return false;
      });
    }

    final repo = _RecordingDoctorShiftNumbersRepository();
    expect(
      repo.items.any(
        (item) => item.numero == 4 && item.consulta == null && item.disponible == false,
      ),
      isTrue,
    );
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
          home: const DoctorShiftNumbersScreen(shiftId: 101),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final numero1Card = findCardForNumber(1);
    final numero2Card = findCardForNumber(2);
    final numero3Card = findCardForNumber(3);
    final numero4Card = findCardForNumber(4);

    expect(find.descendant(of: numero1Card, matching: find.text('Paciente: Carlos Rodríguez')), findsOneWidget);
    expect(find.descendant(of: numero1Card, matching: find.text('Estado: Agendada')), findsOneWidget);
    expect(find.descendant(of: numero1Card, matching: find.text('Llegada: 09:15')), findsOneWidget);

    expect(find.descendant(of: numero3Card, matching: find.text('Paciente: María López')), findsOneWidget);
    expect(find.descendant(of: numero3Card, matching: find.text('Estado: Agendada')), findsOneWidget);
    expect(find.descendant(of: numero3Card, matching: find.text('Llegada: Aún no llegó')), findsOneWidget);

    expect(find.descendant(of: numero2Card, matching: find.text('Disponible')), findsOneWidget);
    expect(find.descendant(of: numero2Card, matching: find.text('Sin reserva')), findsNothing);

    expect(find.descendant(of: numero4Card, matching: find.text('Sin reserva')), findsOneWidget);
    expect(find.descendant(of: numero4Card, matching: find.text('Disponible')), findsNothing);

    expect(find.text('N.º 1'), findsOneWidget);
    expect(find.text('N.º 2'), findsOneWidget);
    expect(find.text('N.º 3'), findsOneWidget);
    expect(find.text('N.º 4'), findsOneWidget);
  });

  testWidgets('la primera llamada usa orden hora y los filtros se propagan al repositorio', (tester) async {
    final repo = _RecordingDoctorShiftNumbersRepository();
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
          home: const DoctorShiftNumbersScreen(shiftId: 101),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(repo.paramsHistory.first.orden, 'hora');

    await tester.tap(find.byType(DropdownButtonFormField<bool?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Con llegada').last);
    await tester.pumpAndSettle();

    final llegadaDropdown = tester.widget<DropdownButtonFormField<bool?>>(
      find.byType(DropdownButtonFormField<bool?>).first,
    );
    expect(llegadaDropdown.initialValue, isTrue);

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hora de llegada').last);
    await tester.pumpAndSettle();

    final ordenDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).at(0),
    );
    expect(ordenDropdown.initialValue, 'horaLlegada');

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desc').last);
    await tester.pumpAndSettle();

    final sentidoDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).at(1),
    );
    expect(sentidoDropdown.initialValue, 'desc');

    expect(repo.paramsHistory.last.shiftId, 101);
    expect(repo.paramsHistory.last.llegada, isTrue);
    expect(repo.paramsHistory.last.orden, 'horaLlegada');
    expect(repo.paramsHistory.last.sentido, 'desc');
  });

  testWidgets('se puede volver a Todos en llegadas y el repositorio recibe null', (tester) async {
    final repo = _RecordingDoctorShiftNumbersRepository();
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
          home: const DoctorShiftNumbersScreen(shiftId: 101),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<bool?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Con llegada').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<bool?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();

    expect(repo.paramsHistory.last.llegada, isNull);
    final llegadaDropdown = tester.widget<DropdownButtonFormField<bool?>>(
      find.byType(DropdownButtonFormField<bool?>).first,
    );
    expect(llegadaDropdown.initialValue, isNull);
  });

  testWidgets('no hay overflow con los filtros visibles en una pantalla angosta', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = _RecordingDoctorShiftNumbersRepository();
    final container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith((ref) async => repo),
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
          home: const DoctorShiftNumbersScreen(shiftId: 101),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Llegada'), findsOneWidget);
    expect(find.text('Orden'), findsOneWidget);
    expect(find.text('Sentido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresca cada 15 segundos y se cancela al desmontar', (tester) async {
    final repo = _RecordingDoctorShiftNumbersRepository();
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
          home: const DoctorShiftNumbersScreen(shiftId: 101),
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

  testWidgets('muestra el aviso discreto si falla un refresco con datos previos', (tester) async {
    final repo = _RecordingDoctorShiftNumbersRepository(
      failOnSecondCall: true,
    );
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
          home: const DoctorShiftNumbersScreen(shiftId: 101),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();

    expect(find.text('No se pudo actualizar. Se sigue mostrando la última información.'), findsOneWidget);
  });
}
