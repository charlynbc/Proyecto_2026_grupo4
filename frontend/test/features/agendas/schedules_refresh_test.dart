import 'dart:async';

import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_filters_controller.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_repository_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_page_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_refresh_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_today_provider.dart';
import 'package:agenda_medica/features/agendas/repositories/schedule_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _today = DateTime.utc(2026, 10, 26);

SchedulePage _pageWith(ScheduleFilters filters, int total) => SchedulePage(
  items: const [],
  page: filters.page,
  size: filters.size,
  total: total,
);

/// Un repositorio que cuenta los pedidos. Con [gate] puesto, los pedidos
/// quedan pendientes hasta completarlo.
class _CountingRepository implements ScheduleRepository {
  final List<ScheduleFilters> calls = [];
  Completer<SchedulePage>? gate;
  int total = 7;

  @override
  Future<SchedulePage> search(ScheduleFilters filters) {
    calls.add(filters);
    return gate?.future ?? Future.value(_pageWith(filters, total));
  }
}

ProviderContainer _container(_CountingRepository repository) {
  return ProviderContainer(
    overrides: [
      schedulesTodayProvider.overrideWithValue(_today),
      scheduleRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
}

/// Lo que hace la pantalla: mirar la página y el refresco. Devuelve las
/// suscripciones para poder soltarlas.
List<ProviderSubscription<Object?>> _watchLikeTheScreen(
  ProviderContainer container,
) => [
  container.listen(schedulesPageProvider, (_, _) {}),
  container.listen(schedulesRefreshProvider, (_, _) {}),
];

void main() {
  group('intervalo', () {
    test('por defecto son 15 segundos', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(schedulesPollIntervalProvider),
        const Duration(seconds: 15),
      );
    });
  });

  group('refresco cada 15 segundos', () {
    testWidgets('a los 14 s hay 1 llamada, a los 15 s 2 y a los 30 s 3', (
      tester,
    ) async {
      final repository = _CountingRepository();
      final container = _container(repository);
      _watchLikeTheScreen(container);
      try {
        await tester.pump();
        expect(repository.calls, hasLength(1));

        await tester.pump(const Duration(seconds: 14));
        expect(repository.calls, hasLength(1));

        await tester.pump(const Duration(seconds: 1));
        expect(repository.calls, hasLength(2));

        await tester.pump(const Duration(seconds: 15));
        expect(repository.calls, hasLength(3));
      } finally {
        container.dispose();
      }
    });

    testWidgets('cada pedido lleva los mismos filtros', (tester) async {
      final repository = _CountingRepository();
      final container = _container(repository);
      _watchLikeTheScreen(container);
      try {
        await tester.pump();
        await tester.pump(const Duration(seconds: 15));

        expect(repository.calls, [
          ScheduleFilters(date: _today),
          ScheduleFilters(date: _today),
        ]);
      } finally {
        container.dispose();
      }
    });

    testWidgets('con un pedido pendiente no hace otro; al completarlo, el '
        'siguiente tick sí', (tester) async {
      final repository = _CountingRepository()
        ..gate = Completer<SchedulePage>();
      final container = _container(repository);
      _watchLikeTheScreen(container);
      try {
        await tester.pump();
        expect(repository.calls, hasLength(1));

        await tester.pump(const Duration(seconds: 15));
        expect(repository.calls, hasLength(1));

        // Se completa a los 16 s; el tick de los 30 s ya puede pedir.
        await tester.pump(const Duration(seconds: 1));
        final gate = repository.gate!;
        repository.gate = null;
        gate.complete(_pageWith(ScheduleFilters(date: _today), 7));
        await tester.pump();
        expect(repository.calls, hasLength(1));

        await tester.pump(const Duration(seconds: 13));
        expect(repository.calls, hasLength(1));

        await tester.pump(const Duration(seconds: 1));
        expect(repository.calls, hasLength(2));
      } finally {
        container.dispose();
      }
    });

    testWidgets('un refresco pendiente también frena el tick siguiente', (
      tester,
    ) async {
      final repository = _CountingRepository();
      final container = _container(repository);
      _watchLikeTheScreen(container);
      try {
        await tester.pump();
        repository.gate = Completer<SchedulePage>();

        await tester.pump(const Duration(seconds: 15));
        expect(repository.calls, hasLength(2));

        await tester.pump(const Duration(seconds: 15));
        expect(repository.calls, hasLength(2));

        final gate = repository.gate!;
        repository.gate = null;
        gate.complete(_pageWith(ScheduleFilters(date: _today), 7));
        await tester.pump();

        await tester.pump(const Duration(seconds: 15));
        expect(repository.calls, hasLength(3));
      } finally {
        container.dispose();
      }
    });

    testWidgets('mientras recarga, la lista anterior sigue a la vista', (
      tester,
    ) async {
      final repository = _CountingRepository()..total = 7;
      final container = _container(repository);
      _watchLikeTheScreen(container);
      try {
        await tester.pump();
        expect(container.read(schedulesPageProvider).value!.total, 7);

        repository
          ..gate = Completer<SchedulePage>()
          ..total = 8;
        await tester.pump(const Duration(seconds: 15));

        final reloading = container.read(schedulesPageProvider);
        expect(reloading.isLoading, isTrue);
        expect(reloading.value, isNotNull);
        expect(reloading.value!.total, 7);

        final gate = repository.gate!;
        repository.gate = null;
        gate.complete(_pageWith(ScheduleFilters(date: _today), 8));
        await tester.pump();

        final reloaded = container.read(schedulesPageProvider);
        expect(reloaded.isLoading, isFalse);
        expect(reloaded.value!.total, 8);
      } finally {
        container.dispose();
      }
    });
  });

  group('al dejar de mirar', () {
    testWidgets('al soltar las suscripciones no hay llamadas nuevas', (
      tester,
    ) async {
      final repository = _CountingRepository();
      final container = _container(repository);
      final subscriptions = _watchLikeTheScreen(container);
      try {
        await tester.pump();
        await tester.pump(const Duration(seconds: 15));
        expect(repository.calls, hasLength(2));

        for (final subscription in subscriptions) {
          subscription.close();
        }
        await tester.pump(const Duration(seconds: 45));

        expect(repository.calls, hasLength(2));
      } finally {
        container.dispose();
      }
    });

    testWidgets('al soltar el container no hay llamadas nuevas', (
      tester,
    ) async {
      final repository = _CountingRepository();
      final container = _container(repository);
      _watchLikeTheScreen(container);
      await tester.pump();
      expect(repository.calls, hasLength(1));

      container.dispose();
      await tester.pump(const Duration(seconds: 45));

      expect(repository.calls, hasLength(1));
    });
  });

  group('con filtros que cambian', () {
    testWidgets('cambiar un filtro hace su pedido propio y el refresco usa '
        'el filtro nuevo', (tester) async {
      final repository = _CountingRepository();
      final container = _container(repository);
      _watchLikeTheScreen(container);
      try {
        await tester.pump();
        await tester.pump(const Duration(seconds: 10));
        expect(repository.calls, hasLength(1));

        container
            .read(scheduleFiltersControllerProvider.notifier)
            .setCi('90000046');
        // Un filtro nuevo rehace la página en el siguiente turno del reloj.
        await tester.pump(const Duration(milliseconds: 1));
        expect(repository.calls, hasLength(2));
        expect(repository.calls.last.ci, '90000046');

        // El tick de los 15 s pide otra vez, ahora con la cédula.
        await tester.pump(const Duration(seconds: 5));
        expect(repository.calls, hasLength(3));
        expect(repository.calls.last.ci, '90000046');
        expect(repository.calls.last.page, 0);
      } finally {
        container.dispose();
      }
    });

    testWidgets('el refresco conserva la página elegida', (tester) async {
      final repository = _CountingRepository();
      final container = _container(repository);
      _watchLikeTheScreen(container);
      try {
        await tester.pump();
        container.read(scheduleFiltersControllerProvider.notifier).goToPage(2);
        await tester.pump(const Duration(milliseconds: 1));
        expect(repository.calls.last.page, 2);

        await tester.pump(const Duration(seconds: 15));

        expect(repository.calls, hasLength(3));
        expect(repository.calls.last.page, 2);
      } finally {
        container.dispose();
      }
    });
  });
}
