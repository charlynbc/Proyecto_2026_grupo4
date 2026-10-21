import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/providers/shift_filters_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  ShiftFiltersController notifier() =>
      container.read(shiftFiltersControllerProvider.notifier);
  ShiftFilters filters() => container.read(shiftFiltersControllerProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    // Con alguien mirando: el provider es autoDispose y, sin esto, se
    // descartaría entre una lectura y la siguiente.
    container.listen(shiftFiltersControllerProvider, (_, _) {});
  });

  group('clear', () {
    test('vuelve al estado inicial desde filtros, orden, sentido y página '
        'cambiados', () {
      notifier().search(
        doctorId: 3,
        specialtyId: 2,
        weekday: 4,
        fromDate: DateTime.utc(2026, 10, 1),
        toDate: DateTime.utc(2026, 12, 1),
        shiftState: ShiftState.suspended,
      );
      notifier().sortBy(ShiftOrder.doctor, ascending: false);
      notifier().goToPage(2);
      expect(filters(), isNot(const ShiftFilters()));

      notifier().clear();

      expect(filters(), const ShiftFilters());
    });

    test('deja la página en 0', () {
      notifier().goToPage(3);
      expect(filters().page, 3);

      notifier().clear();

      expect(filters().page, 0);
    });

    test('deja el orden por fecha y el sentido ascendente', () {
      notifier().sortBy(ShiftOrder.specialty, ascending: false);

      notifier().clear();

      expect(filters().order, ShiftOrder.date);
      expect(filters().ascending, isTrue);
    });

    test('con todo ya limpio no cambia nada', () {
      notifier().clear();

      expect(filters(), const ShiftFilters());
    });
  });
}
