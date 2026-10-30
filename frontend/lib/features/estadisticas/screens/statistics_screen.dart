import 'package:flutter/material.dart';

import '../../auth/widgets/logout_button.dart';
import '../tabs/appointment_statistics_tab.dart';
import '../tabs/shift_statistics_tab.dart';
import '../tabs/specialty_statistics_tab.dart';

const String kStatisticsPath = '/admin/estadisticas';

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
            // Con tres textos largos no entran en una pantalla angosta.
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                key: Key('stats-tab-specialties'),
                text: 'Demanda por especialidad',
              ),
              Tab(key: Key('stats-tab-shifts'), text: 'Utilización por turno'),
              Tab(
                key: Key('stats-tab-appointments'),
                text: 'Consultas por estado',
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
