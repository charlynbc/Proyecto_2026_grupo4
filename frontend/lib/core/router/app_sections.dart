import 'package:flutter/material.dart';

import '../../features/auth/models/user_role.dart';

/// Una sección del menú de un rol. Su ruta es `<prefijo del rol>/<slug>`.
class AppSection {
  const AppSection(this.slug, this.label, this.icon, this.selectedIcon);

  final String slug;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Secciones de cada rol, en el orden del menú. La primera es la home del
/// rol. Es una comodidad de navegación: la autorización real es del servidor.
const Map<UserRole, List<AppSection>> kSectionsByRole = {
  UserRole.socio: [
    AppSection(
      'disponibilidad',
      'Disponibilidad',
      Icons.event_available_outlined,
      Icons.event_available,
    ),
    AppSection(
      'consultas',
      'Mis consultas',
      Icons.event_note_outlined,
      Icons.event_note,
    ),
    AppSection(
      'historia',
      'Historia clínica',
      Icons.medical_information_outlined,
      Icons.medical_information,
    ),
    AppSection(
      'cartelera',
      'Cartelera',
      Icons.campaign_outlined,
      Icons.campaign,
    ),
  ],
  UserRole.funcionario: [
    AppSection(
      'turnos',
      'Turnos',
      Icons.calendar_month_outlined,
      Icons.calendar_month,
    ),
    AppSection(
      'llegada',
      'Llegada',
      Icons.how_to_reg_outlined,
      Icons.how_to_reg,
    ),
    AppSection(
      'agendas',
      'Agendas',
      Icons.view_agenda_outlined,
      Icons.view_agenda,
    ),
  ],
  UserRole.medico: [
    AppSection(
      'turnos',
      'Mis turnos',
      Icons.calendar_month_outlined,
      Icons.calendar_month,
    ),
  ],
  UserRole.administrador: [
    AppSection('usuarios', 'Usuarios', Icons.people_outline, Icons.people),
    AppSection(
      'especialidades',
      'Especialidades',
      Icons.local_hospital_outlined,
      Icons.local_hospital,
    ),
    AppSection(
      'consultorios',
      'Consultorios',
      Icons.meeting_room_outlined,
      Icons.meeting_room,
    ),
    AppSection(
      'estadisticas',
      'Estadísticas',
      Icons.bar_chart_outlined,
      Icons.bar_chart,
    ),
  ],
};

extension UserRoleSections on UserRole {
  List<AppSection> get sections => kSectionsByRole[this]!;

  String sectionPath(AppSection section) => '$routePrefix/${section.slug}';

  /// Home del rol: su primera sección.
  String get homePath => sectionPath(sections.first);
}
