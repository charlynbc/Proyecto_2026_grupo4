import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editar una novedad es PUT /api/admin/anuncios/{id}', () {
    expect(ApiRoutes.adminAnnouncementUpdate(42), '/api/admin/anuncios/42');
  });
}
