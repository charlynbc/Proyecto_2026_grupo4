import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../widgets/new_user_form.dart';
import 'user_routes.dart';

/// Alta de un usuario (RF-31, CU 3.5.2).
class NewUserScreen extends StatelessWidget {
  const NewUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kUsersPath),
        ),
        title: const Text('Alta de usuario'),
      ),
      body: const CenteredContent(maxWidth: 560, child: NewUserForm()),
    );
  }
}
