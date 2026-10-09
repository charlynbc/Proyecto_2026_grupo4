# Agenda Médica

## Firebase

El proyecto usa `firebase_core` y `firebase_analytics`. No se instala Firebase
con npm porque el frontend está construido con Flutter.

Para instalar las dependencias:

```bash
flutter pub get
```

La configuración web está en `lib/firebase_options.dart` y se inicializa desde
`lib/main.dart`.

Para habilitar Android, registrar en Firebase la aplicación con este package:

```text
uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica
```

Después ejecutar desde esta carpeta:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=grupo4-agendamedica --platforms=android,web
flutter pub get
```

El proceso generará `android/app/google-services.json` y reemplazará las
opciones web-only por la configuración multiplataforma.

Mientras Android no esté registrado, Firebase se inicializa únicamente en web
para que la aplicación móvil pueda seguir arrancando.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
