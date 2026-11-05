import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/agenda/screens/appointments_pending_screen.dart';
import 'package:agenda_medica/features/agenda/screens/availability_screen.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Entra como Ana Rodríguez, la socia de los datos de prueba.
Future<void> _loginAsMember(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final person = TestData.people.firstWhere((p) => p.role == kRoleMember);
  final repo = await container.read(authRepositoryProvider.future);
  final done = repo.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.socio,
  );
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

/// Deja pasar la latencia de los repositories falsos (300 ms).
Future<void> _wait(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('después de agendar, "Mis consultas" lleva a la lista con la '
      'consulta nueva', (tester) async {
    final container = await pumpApp(tester);
    await _loginAsMember(tester, container);
    expect(locationOf(container), '/socio/disponibilidad');

    // Medicina General no pide pase. Se agenda el último número de la lista,
    // que queda siempre dentro de la anticipación máxima y lejos de la
    // consulta agendada de la semilla.
    await tester.tap(find.byKey(const Key('filter-specialty')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medicina General').last);
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('availability-search-button'));
    await tester.ensureVisible(search);
    await tester.pumpAndSettle();
    await tester.tap(search);
    await _wait(tester);
    final book = find.widgetWithText(FilledButton, 'Agendar').last;
    await tester.ensureVisible(book);
    await tester.pumpAndSettle();
    await tester.tap(book);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await _wait(tester);
    expect(find.text('Consulta agendada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('booked-view-appointments')));
    await _wait(tester);

    expect(locationOf(container), '/socio/consultas');
    expect(find.byType(AppointmentsPendingScreen), findsOneWidget);
    expect(find.byType(AvailabilityScreen), findsNothing);
    // La semilla de Ana tiene las consultas 1 a 3: la nueva es la 4.
    expect(find.byKey(const Key('appointment-4')), findsOneWidget);
    expect(find.text('Consulta agendada'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('Ana agenda Cardiología con su pase y la ve en "Mis consultas"', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await _loginAsMember(tester, container);

    await tester.tap(find.byKey(const Key('filter-specialty')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cardiología').last);
    await _wait(tester);
    final book = find.widgetWithText(FilledButton, 'Agendar').last;
    await tester.ensureVisible(book);
    await tester.pumpAndSettle();
    await tester.tap(book);
    await _wait(tester);

    // El pase 1 de la semilla vence 25 días después de hoy; "hoy" es el de
    // UruguayTime.today(), el mismo con que la app arma la base falsa.
    final expires = formatUiDate(
      UruguayTime.today().add(const Duration(days: 25)),
    );
    expect(
      find.text(
        'Esta especialidad requiere pase. Se usará el pase a Cardiología, '
        'vigente hasta $expires. Se consume al confirmar.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await _wait(tester);
    expect(find.text('Consulta agendada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('booked-view-appointments')));
    await _wait(tester);

    expect(locationOf(container), '/socio/consultas');
    final card = find.byKey(const Key('appointment-4'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Cardiología · Agendada')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('Esteban Silva')),
      findsOneWidget,
    );
    await unmountApp(tester);
  });
}
