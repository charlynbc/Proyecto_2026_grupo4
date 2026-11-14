import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

final _appointment = Appointment(
  id: 9001,
  status: 'AGENDADA',
  date: DateTime.utc(2026, 11, 25),
  number: 4,
  startMinutes: 600,
  endMinutes: 630,
  doctor: DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez'),
  specialty: Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
  clinic: Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  referralId: null,
  bookedAt: DateTime.utc(2026, 11, 1, 15),
  cancelledAt: null,
  cancellationReason: null,
);

class _Repository implements AppointmentHistoryRepository {
  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async =>
      throw UnimplementedError();

  @override
  Future<Appointment> get(int id) async => _appointment;
}

/// Abre el detalle como la app: apilado sobre otra pantalla, así el AppBar
/// lleva la flecha de volver además de los íconos de la cuenta.
Future<void> _openDetail(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => _Repository(),
        ),
      ],
      child: MaterialApp(
        theme: appTheme,
        navigatorKey: navigator,
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => const AppointmentDetailScreen(id: 9001),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  for (final scale in [1.0, 1.3]) {
    testWidgets('a 360 dp con texto x$scale el título del detalle no se '
        'corta y dice Consulta', (tester) async {
      await _openDetail(tester, width: 360, textScale: scale);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final title = appBar.title! as Text;
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byWidget(title),
        ),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(title.data, 'Consulta');
      expect(tester.takeException(), isNull);
    });
  }
}
