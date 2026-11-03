import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rutas de cargas masivas', () {
    test('vista previa de la carga de especialidades', () {
      expect(
        ApiRoutes.specialtiesImportPreview,
        '/api/especialidades/importaciones/previsualizar',
      );
    });

    test('confirmar la carga de especialidades', () {
      expect(
        ApiRoutes.specialtiesImportConfirm,
        '/api/especialidades/importaciones/confirmar',
      );
    });

    test('vista previa de la carga de usuarios', () {
      expect(
        ApiRoutes.usersImportPreview,
        '/api/usuarios/importaciones/previsualizar',
      );
    });

    test('confirmar la carga de usuarios', () {
      expect(
        ApiRoutes.usersImportConfirm,
        '/api/usuarios/importaciones/confirmar',
      );
    });

    test('las cuatro rutas estan en ApiRoutes.all', () {
      expect(
        ApiRoutes.all,
        containsAll([
          '/api/especialidades/importaciones/previsualizar',
          '/api/especialidades/importaciones/confirmar',
          '/api/usuarios/importaciones/previsualizar',
          '/api/usuarios/importaciones/confirmar',
        ]),
      );
    });
  });
}
