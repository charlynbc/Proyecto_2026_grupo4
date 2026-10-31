import 'package:flutter/material.dart';

import '../../auth/widgets/logout_button.dart';
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

/// Estadísticas del administrador (RF-39, RF-40 y RF-41): una pestaña por
/// estadística. Cada pestaña es un widget propio en `tabs/`, así que se
/// arman por separado sin pisarse en esta pantalla.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas'),
          actions: const [LogoutButton()],
          bottom: const TabBar(
            // Las tres pestañas se reparten el ancho y se ven siempre
            // enteras: con la barra desplazable, la tercera quedaba fuera de
            // la pantalla sin ninguna pista. Con 8 px a cada lado, la palabra
            // más larga ("especialidad") entra incluso a 320 px.
            labelPadding: EdgeInsets.symmetric(horizontal: 8),
            tabs: [
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
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SpecialtyStatisticsTab(),
            ShiftStatisticsTab(),
            AppointmentStatisticsTab(),
          ],
        ),
      ),
    );
  }
}
