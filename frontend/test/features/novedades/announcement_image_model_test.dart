import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  int id = 1,
  int order = 0,
  String url = 'https://ejemplo.org/a.png',
}) => {'id': id, 'orden': order, 'url': url};

final _rejected = throwsA(
  isA<FormatException>().having((e) => e.message, 'message', 'Imagen inválida'),
);

void main() {
  group('URL permitida', () {
    for (final url in [
      'https://ejemplo.org/a.png',
      'http://ejemplo.org/a.png',
      'HTTPS://EJEMPLO.ORG/a.png',
    ]) {
      test('"$url" pasa y conserva id, orden y url', () {
        final image = AnnouncementImage.fromJson(
          _json(id: 7, order: 2, url: url),
        );

        expect(image.id, 7);
        expect(image.order, 2);
        expect(image.url, url);
      });
    }

    test('el orden 0 y el id 1 son válidos', () {
      final image = AnnouncementImage.fromJson(_json());

      expect(image.id, 1);
      expect(image.order, 0);
    });
  });

  group('URL rechazada', () {
    for (final url in [
      'ftp://ejemplo.org/a.png',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'data:image/png;base64,AAAA',
      'https:///sin-host',
      'https://:8080/x',
      'https:sin-host',
      '',
    ]) {
      test('"$url" lanza FormatException', () {
        expect(() => AnnouncementImage.fromJson(_json(url: url)), _rejected);
      });
    }
  });

  group('id y orden fuera de rango', () {
    for (final id in [0, -1]) {
      test('el id $id lanza FormatException', () {
        expect(() => AnnouncementImage.fromJson(_json(id: id)), _rejected);
      });
    }

    test('el orden -1 lanza FormatException', () {
      expect(() => AnnouncementImage.fromJson(_json(order: -1)), _rejected);
    });
  });
}
