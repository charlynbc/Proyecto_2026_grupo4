import 'package:flutter/material.dart';

import '../../../core/widgets/centered_content.dart';
import '../widgets/new_weekly_shift_form.dart';

/// Alta de un turno semanal del funcionario (RF-13, CU 3.3.1).
class NewWeeklyShiftScreen extends StatelessWidget {
  const NewWeeklyShiftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo turno semanal')),
      body: const CenteredContent(maxWidth: 700, child: NewWeeklyShiftForm()),
    );
  }
}
