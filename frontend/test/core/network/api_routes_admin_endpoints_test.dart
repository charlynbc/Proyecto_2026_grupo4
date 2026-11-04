import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rutas de administración (filas 56 a 62)', () {
    test('vista previa de la carga masiva de consultorios', () {
      expect(
        ApiRoutes.clinicsImportPreview,
        '/api/consultorios/importaciones/previsualizar',
      );
    });

    test('confirmación de la carga masiva de consultorios', () {
      expect(
        ApiRoutes.clinicsImportConfirm,
        '/api/consultorios/importaciones/confirmar',
      );
    });

    test('corregir una especialidad', () {
      expect(ApiRoutes.specialty(12), '/api/especialidades/12');
    });

    test('corregir un consultorio', () {
      expect(ApiRoutes.clinic(7), '/api/consultorios/7');
    });

    test('corregir los datos de una cuenta', () {
      expect(ApiRoutes.user(42), '/api/usuarios/42');
    });

    test('inactivar una cuenta de empleado', () {
      expect(ApiRoutes.userDeactivate(42), '/api/usuarios/42/inactivar');
    });

    test('reactivar una cuenta de empleado', () {
      expect(ApiRoutes.userReactivate(42), '/api/usuarios/42/reactivar');
    });

    test('ApiRoutes.all incluye las siete rutas, con id 1 donde lleva id', () {
      expect(
        ApiRoutes.all,
        containsAll(<String>[
          '/api/consultorios/importaciones/previsualizar',
          '/api/consultorios/importaciones/confirmar',
          '/api/especialidades/1',
          '/api/consultorios/1',
          '/api/usuarios/1',
          '/api/usuarios/1/inactivar',
          '/api/usuarios/1/reactivar',
        ]),
      );
    });

    test('ApiRoutes.all no tiene rutas repetidas', () {
      expect(ApiRoutes.all.toSet().length, ApiRoutes.all.length);
    });
  });
}
