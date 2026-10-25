import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Falla siempre y cuenta cuántas veces se le pidió el listado.
class _FailingHistoryRepository implements AppointmentHistoryRepository {
  int listCalls = 0;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    listCalls++;
    throw const ApiException('No se pudo cargar de prueba.');
  }

  @override
  Future<Appointment> get(int id) async => throw UnimplementedError();
}

void main() {
  // Riverpod 3 reintenta solo los providers que fallan (el primer reintento a
  // los 200 ms) y mientras tanto el estado es "cargando": la pantalla no
  // llegaría a mostrar el error. El provider del historial no debe reintentar.
  testWidgets('una falla del repositorio es un AsyncError enseguida y se '
      'pide una sola vez', (tester) async {
    final repository = _FailingHistoryRepository();
    final container = ProviderContainer(
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    addTearDown(container.dispose);
    const query = AppointmentHistoryQuery();
    container.listen(
      appointmentHistoryProvider(query),
      (_, _) {},
      onError: (_, _) {},
    );

    await tester.pump(const Duration(milliseconds: 1));
    final state = container.read(appointmentHistoryProvider(query));

    expect(state, isA<AsyncError<AppointmentHistoryPage>>());
    expect(state.isLoading, isFalse);
    expect(state.retrying, isFalse);
    expect(repository.listCalls, 1);

    // Más tiempo que el primer reintento de Riverpod: no vuelve a pedir.
    await tester.pump(const Duration(seconds: 2));

    expect(
      container.read(appointmentHistoryProvider(query)),
      isA<AsyncError>(),
    );
    expect(repository.listCalls, 1);
  });
}
