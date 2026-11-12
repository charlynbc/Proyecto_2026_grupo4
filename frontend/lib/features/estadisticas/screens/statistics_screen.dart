import 'package:flutter/material.dart';

import '../../auth/widgets/logout_button.dart';
import '../tabs/absence_statistics_tab.dart';
import '../tabs/appointment_statistics_tab.dart';
import '../tabs/shift_statistics_tab.dart';
import '../tabs/specialty_statistics_tab.dart';

const String kStatisticsPath = '/admin/estadisticas';

/// El texto de una pestaña: hasta dos líneas, centrado, que corta solo en los
/// espacios.
class _TabLabel extends StatelessWidget {
  const _TabLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center, maxLines: 2);
}

/// Estadísticas del administrador (RF-39, RF-40, RF-41 y RF-42): una pestaña
/// por estadística. Cada pestaña es un widget propio en `tabs/`, así que se
/// arman por separado sin pisarse en esta pantalla.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // En una pantalla angosta cada pestaña queda chica: 12 px y 2 px de
    // margen hacen entrar la palabra más larga a 320 px. Más ancha, la letra
    // de siempre.
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas'),
          actions: const [LogoutButton()],
          bottom: TabBar(
            // Las cuatro pestañas se reparten el ancho y se ven siempre
            // enteras: con la barra desplazable, la última quedaba fuera de
            // la pantalla sin ninguna pista.
            labelPadding: EdgeInsets.symmetric(horizontal: narrow ? 2 : 8),
            labelStyle: narrow
                ? const TextStyle(fontSize: 12, height: 1.15)
                : null,
            unselectedLabelStyle: narrow
                ? const TextStyle(fontSize: 12, height: 1.15)
                : null,
            tabs: const [
              // `Tab(text:)` no pasa a otra línea (usa `softWrap: false`), así
              // que cada etiqueta es un `Text` de hasta dos líneas, que corta
              // solo en los espacios.
              Tab(
                key: Key('stats-tab-specialties'),
                child: _TabLabel('Demanda por especialidad'),
              ),
              Tab(
                key: Key('stats-tab-shifts'),
                child: _TabLabel('Utilización por turno'),
              ),
              Tab(
                key: Key('stats-tab-appointments'),
                child: _TabLabel('Consultas por estado'),
              ),
              Tab(
                key: Key('stats-tab-absences'),
                child: _TabLabel('Inasistencias'),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SpecialtyStatisticsTab(),
            ShiftStatisticsTab(),
            AppointmentStatisticsTab(),
            AbsenceStatisticsTab(),
          ],
        ),
      ),
    );
  }
}
