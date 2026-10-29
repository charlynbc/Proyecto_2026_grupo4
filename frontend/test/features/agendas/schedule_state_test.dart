import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_filters_controller.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_repository_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_page_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_today_provider.dart';
import 'package:agenda_medica/features/agendas/repositories/api_schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/schedule_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _today = DateTime.utc(2026, 10, 26);

/// Un repositorio que anota los filtros que recibe y responde una página
/// vacía, o falla con [failure].
class _RecordingRepository implements ScheduleRepository {
  final List<ScheduleFilters> calls = [];
  Object? failure;

  @override
  Future<SchedulePage> search(ScheduleFilters filters) async {
    calls.add(filters);
    final error = failure;
    if (error != null) throw error;
    return SchedulePage(
      items: const [],
      page: filters.page,
      size: filters.size,
      total: 0,
    );
  }
}

ProviderContainer _container(_RecordingRepository repository) {
  final container = ProviderContainer(
    overrides: [
      schedulesTodayProvider.overrideWithValue(_today),
      scheduleRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Mantiene viva la página (es `autoDispose`) y espera a que termine de
/// cargar.
Future<void> _load(ProviderContainer container) async {
  container.listen(schedulesPageProvider, (_, _) {});
  await container.read(schedulesPageProvider.future);
}

ScheduleFiltersController _controller(ProviderContainer container) =>
    container.read(scheduleFiltersControllerProvider.notifier);

ScheduleFilters _filters(ProviderContainer container) =>
    container.read(scheduleFiltersControllerProvider);

void main() {
  group('scheduleRepositoryProvider', () {
    ProviderContainer containerFor({required bool useFakes}) {
      final container = ProviderContainer(
        overrides: [
          useFakesProvider.overrideWithValue(useFakes),
          // Un Dio liso: el real configura cookies con path_provider.
          dioProvider.overrideWith((ref) async => Dio()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('con USE_FAKES=true devuelve el repositorio falso', () async {
      final repository = await containerFor(useFakes: true)
          .read(scheduleRepositoryProvider.future);

      expect(repository, isA<FakeScheduleRepository>());
    });

    test('sin USE_FAKES devuelve el repositorio real', () async {
      final repository = await containerFor(useFakes: false)
          .read(scheduleRepositoryProvider.future);

      expect(repository, isA<ApiScheduleRepository>());
    });
  });

  group('schedulesTodayProvider', () {
    test('por defecto es hoy en Uruguay', () {
      final before = UruguayTime.today();
      final value = ProviderContainer().read(schedulesTodayProvider);
      final after = UruguayTime.today();

      expect(value, anyOf(before, after));
    });
  });

  group('filtros iniciales', () {
    test('arrancan con la fecha de hoy y los valores por defecto', () {
      final container = _container(_RecordingRepository());

      expect(_filters(container), ScheduleFilters(date: _today));
      expect(_filters(container).date, DateTime.utc(2026, 10, 26));
    });

    test('el primer pedido lleva fecha, orden, sentido, page y size', () async {
      final repository = _RecordingRepository();
      final container = _container(repository);

      await _load(container);

      expect(repository.calls, hasLength(1));
      expect(repository.calls.single.toQueryParameters(), {
        'fecha': '2026-10-26',
        'orden': 'fechaHora',
        'sentido': 'asc',
        'page': 0,
        'size': 20,
      });
    });
  });

  group('cambiar un filtro vuelve a la primera página', () {
    // Cada caso cambia un filtro estando en la página 3.
    final changes = <String, void Function(ScheduleFiltersController)>{
      'la cédula': (c) => c.setCi('9.000.004-6'),
      'el identificador': (c) => c.setAppointmentId('15'),
      'el médico': (c) => c.setDoctorId(17),
      'la fecha': (c) => c.setDate(DateTime.utc(2026, 10, 27)),
      'el estado': (c) => c.setStatus('NO_ATENDIDA'),
      'la llegada': (c) => c.setArrived(true),
      'el orden': (c) => c.setOrder(ScheduleOrder.arrivalTime),
      'el sentido': (c) => c.setAscending(false),
    };

    for (final entry in changes.entries) {
      test(entry.key, () async {
        final repository = _RecordingRepository();
        final container = _container(repository);
        await _load(container);
        _controller(container).goToPage(3);
        await container.read(schedulesPageProvider.future);
        expect(repository.calls.last.page, 3);

        entry.value(_controller(container));
        await container.read(schedulesPageProvider.future);

        expect(repository.calls, hasLength(3));
        expect(repository.calls.last.page, 0);
        expect(_filters(container).page, 0);
      });
    }

    test('cada cambio llega al pedido', () async {
      final repository = _RecordingRepository();
      final container = _container(repository);
      await _load(container);

      _controller(container)
        ..setCi('9.000.004-6')
        ..setAppointmentId('15')
        ..setDoctorId(17)
        ..setDate(DateTime.utc(2026, 10, 27))
        ..setStatus('NO_ATENDIDA')
        ..setArrived(false)
        ..setOrder(ScheduleOrder.arrivalTime)
        ..setAscending(false);
      await container.read(schedulesPageProvider.future);

      expect(repository.calls.last.toQueryParameters(), {
        'ci': '90000046',
        'consultaId': 15,
        'medicoId': 17,
        'fecha': '2026-10-27',
        'estado': 'NO_ATENDIDA',
        'llegada': false,
        'orden': 'horaLlegada',
        'sentido': 'desc',
        'page': 0,
        'size': 20,
      });
    });

    test('un filtro se borra pasando null', () async {
      final repository = _RecordingRepository();
      final container = _container(repository);
      await _load(container);
      _controller(container)
        ..setDoctorId(17)
        ..setArrived(true)
        ..setCi('9.000.004-6');

      _controller(container)
        ..setDoctorId(null)
        ..setArrived(null)
        ..setCi(null);

      expect(_filters(container), ScheduleFilters(date: _today));
    });

    test('un cambio no pisa los demás filtros', () async {
      final container = _container(_RecordingRepository());
      _controller(container)
        ..setDoctorId(17)
        ..setStatus('AGENDADA');

      expect(_filters(container).doctorId, 17);
      expect(_filters(container).status, 'AGENDADA');
    });
  });

  group('goToPage', () {
    test('hace el pedido con esa página y conserva los filtros', () async {
      final repository = _RecordingRepository();
      final container = _container(repository);
      await _load(container);
      _controller(container).setDoctorId(17);
      await container.read(schedulesPageProvider.future);

      _controller(container).goToPage(3);
      await container.read(schedulesPageProvider.future);

      expect(repository.calls.last.page, 3);
      expect(repository.calls.last.doctorId, 17);
      expect(repository.calls.last.date, _today);
    });
  });

  group('clear', () {
    test('vuelve a los valores por defecto con la fecha de hoy', () async {
      final repository = _RecordingRepository();
      final container = _container(repository);
      await _load(container);
      _controller(container)
        ..setCi('9.000.004-6')
        ..setDate(DateTime.utc(2026, 11, 2))
        ..setStatus('ATENDIDA')
        ..setArrived(true)
        ..setOrder(ScheduleOrder.arrivalTime)
        ..setAscending(false)
        ..goToPage(2);
      await container.read(schedulesPageProvider.future);

      _controller(container).clear();
      await container.read(schedulesPageProvider.future);

      expect(_filters(container), ScheduleFilters(date: _today));
      expect(repository.calls.last.toQueryParameters(), {
        'fecha': '2026-10-26',
        'orden': 'fechaHora',
        'sentido': 'asc',
        'page': 0,
        'size': 20,
      });
    });
  });

  group('errores', () {
    test(
      'un 400 deja la página en error con el mensaje del servidor',
      () async {
        final repository = _RecordingRepository()
          ..failure = const ScheduleValidationException(
            'ci debe ser una cedula valida',
          );
        final container = _container(repository);
        container.listen(schedulesPageProvider, (_, _) {});

        await expectLater(
          container.read(schedulesPageProvider.future),
          throwsA(isA<ScheduleValidationException>()),
        );

        final state = container.read(schedulesPageProvider);
        expect(state.hasError, isTrue);
        expect(
          (state.error! as ScheduleValidationException).message,
          'ci debe ser una cedula valida',
        );
      },
    );

    test('no reintenta sola', () async {
      final repository = _RecordingRepository()
        ..failure = const ScheduleValidationException('ci invalida');
      final container = _container(repository);
      container.listen(schedulesPageProvider, (_, _) {});
      await expectLater(
        container.read(schedulesPageProvider.future),
        throwsA(isA<ScheduleValidationException>()),
      );

      // Riverpod reintenta a los 200 ms si no se lo desactiva.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(repository.calls, hasLength(1));
    });

    test('se recupera al corregir el filtro', () async {
      final repository = _RecordingRepository()
        ..failure = const ScheduleValidationException('ci invalida');
      final container = _container(repository);
      container.listen(schedulesPageProvider, (_, _) {});
      await expectLater(
        container.read(schedulesPageProvider.future),
        throwsA(isA<ScheduleValidationException>()),
      );

      repository.failure = null;
      _controller(container).setCi('90000046');
      final page = await container.read(schedulesPageProvider.future);

      expect(page.total, 0);
      expect(container.read(schedulesPageProvider).hasError, isFalse);
      expect(repository.calls.last.ci, '90000046');
    });
  });
}
