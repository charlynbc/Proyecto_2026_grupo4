import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la lista de avisos del socio (fila 32)', () {
    expect(ApiRoutes.notifications, '/api/notificaciones');
  });
}
