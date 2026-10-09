import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    throw UnsupportedError(
      'Firebase todavía no está configurado para esta plataforma. '
      'Ejecuta flutterfire configure después de registrar la app móvil.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAk4dh39KnNpQ5dKi1jTr8rSYnFiRKYJRE',
    appId: '1:405535204368:web:a08b652f95af2fa5859695',
    messagingSenderId: '405535204368',
    projectId: 'grupo4-agendamedica',
    authDomain: 'grupo4-agendamedica.firebaseapp.com',
    storageBucket: 'grupo4-agendamedica.firebasestorage.app',
    measurementId: 'G-3C55YNN8KV',
  );
}