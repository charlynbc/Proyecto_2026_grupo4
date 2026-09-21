import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Pantalla mínima para el estado `checking` de sessionProvider, mientras
/// se espera la respuesta del bootstrap (POST /api/auth/refresh). Sin esto,
/// login aparece medio segundo antes de saltar a home (o viceversa), lo que
/// se ve como un bug.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/images/logo.svg', height: 180),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
