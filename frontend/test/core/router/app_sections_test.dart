import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('secciones del socio', () {
    final sections = kSectionsByRole[UserRole.socio]!;

    test('son seis, con Avisos antes de Cartelera', () {
      expect(
        [for (final s in sections) s.slug],
        [
          'inicio',
          'disponibilidad',
          'consultas',
          'historia',
          'avisos',
          'cartelera',
        ],
      );
      expect(
        [for (final s in sections) s.label],
        [
          'Inicio',
          'Reservar consulta',
          'Mis consultas',
          'Historia clínica',
          'Avisos',
          'Cartelera',
        ],
      );
    });

    test('Avisos tiene su ícono, relleno cuando está elegida', () {
      final avisos = sections.firstWhere((s) => s.slug == 'avisos');

      expect(avisos.icon, Icons.notifications_outlined);
      expect(avisos.selectedIcon, Icons.notifications);
    });

    test('Inicio sigue siendo la primera: es la home del rol', () {
      expect(sections.first.slug, 'inicio');
    });
  });

  test('los otros roles no ganaron secciones', () {
    expect(kSectionsByRole[UserRole.funcionario], hasLength(5));
    expect(kSectionsByRole[UserRole.medico], hasLength(5));
    expect(kSectionsByRole[UserRole.administrador], hasLength(6));
  });
}
