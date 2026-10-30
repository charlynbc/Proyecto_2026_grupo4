import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schedule_entry_test.dart' show entryJson;

Map<String, dynamic> pageJson({
  int page = 0,
  int size = 20,
  int total = 1,
  List<Object?>? items,
}) => {
  'items': items ?? [entryJson()],
  'page': page,
  'size': size,
  'total': total,
};

SchedulePage page({int page = 0, int size = 20, int total = 0}) =>
    SchedulePage.fromJson(
      pageJson(page: page, size: size, total: total, items: const []),
    );

void main() {
  group('SchedulePage.fromJson', () {
    test('lee items, page, size y total', () {
      final result = SchedulePage.fromJson(
        pageJson(
          page: 2,
          size: 20,
          total: 41,
          items: [entryJson(), entryJson(arrivedAt: null)],
        ),
      );

      expect(result.items, hasLength(2));
      expect(result.items[0].appointmentId, 9001);
      expect(result.items[0].arrivalTime, '08:55');
      expect(result.items[1].arrivalTime, isNull);
      expect(result.page, 2);
      expect(result.size, 20);
      expect(result.total, 41);
    });

    test('una lista vacía es una página sin items', () {
      final result = page();

      expect(result.items, isEmpty);
      expect(result.total, 0);
    });

    test('un item con estado desconocido es un error de formato', () {
      expect(
        () => SchedulePage.fromJson(
          pageJson(items: [entryJson(status: 'PENDIENTE')]),
        ),
        throwsFormatException,
      );
    });

    test('sin "items" es un error de lectura', () {
      final json = pageJson()..remove('items');

      expect(
        () => SchedulePage.fromJson(json),
        throwsA(anyOf(isA<FormatException>(), isA<TypeError>())),
      );
    });
  });

  group('páginas', () {
    test(
      'sin resultados hay una sola página y no hay anterior ni siguiente',
      () {
        final result = page(total: 0);

        expect(result.pageCount, 1);
        expect(result.hasPrevious, isFalse);
        expect(result.hasNext, isFalse);
      },
    );

    test('41 resultados de a 20 son 3 páginas', () {
      expect(page(total: 41).pageCount, 3);
    });

    test('40 resultados de a 20 son 2 páginas', () {
      expect(page(total: 40).pageCount, 2);
    });

    test('la primera página tiene siguiente y no anterior', () {
      final result = page(page: 0, total: 41);

      expect(result.hasPrevious, isFalse);
      expect(result.hasNext, isTrue);
    });

    test('la del medio tiene anterior y siguiente', () {
      final result = page(page: 1, total: 41);

      expect(result.hasPrevious, isTrue);
      expect(result.hasNext, isTrue);
    });

    test('la última tiene anterior y no siguiente', () {
      final result = page(page: 2, total: 41);

      expect(result.hasPrevious, isTrue);
      expect(result.hasNext, isFalse);
    });

    test('con 40 resultados de a 20, la página 1 es la última', () {
      expect(page(page: 1, total: 40).hasNext, isFalse);
    });
  });
}
