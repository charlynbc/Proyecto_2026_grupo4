# Médica Oriental

Aplicación Flutter (web y Android) del sistema de reserva de consultas médicas.
Todos los comandos se corren desde esta carpeta (`frontend/`).

```bash
flutter pub get
```

## Correr con datos de prueba (sin backend)

```bash
flutter run -d chrome --web-port=5173 --dart-define=USE_FAKES=true
```

Con `USE_FAKES=true` la app no hace ninguna llamada HTTP: cada repository usa
datos en memoria (`lib/core/fakes/datos_prueba.dart`). El estado se pierde al
recargar la página. Sin esa variable (por defecto `USE_FAKES=false`) la app
usa la API real.

**Login con datos de prueba.** Se acepta cualquier cédula de la tabla con la
contraseña `prueba1234`, y la sesión queda con el rol de esa persona:

| Cédula | Persona | Rol |
|---|---|---|
| `12345672` | Ana Rodríguez | SOCIO |
| `23456783` | Bruno Pereira | FUNCIONARIO |
| `34567894` | Dra. Carla Méndez | MEDICO |
| `45678905` | Diego Fernández | ADMINISTRADOR |
| `56789016` | Dr. Esteban Silva | MEDICO |
| `67890127` | Dra. Florencia Acosta | MEDICO |

Cualquier otra cédula o contraseña da el error de credenciales incorrectas.
Como en el servidor, el acceso tiene que coincidir con la cuenta: Ana (SOCIO)
entra por "Socio" y los demás por "Empleado" (solo web, en `/login?acceso=empleado`);
por el acceso equivocado el error es el mismo.

**Primer ingreso con datos de prueba.** El pedido de enlace siempre responde lo
mismo. Para activar una cuenta abrí `/#/primer-ingreso?token=cualquiera`; los
tokens `vencido` y `usado` simulan un enlace que ya no sirve.

**Errores para ver en pantalla.** Los fakes devuelven los mismos errores que la
API: al reservar, algunos horarios aparecen libres pero fallan como "otro socio
lo tomó recién" (409) o "el horario ya comenzó" (400); cancelar una reserva ya
cancelada falla como reserva inexistente. Los turnos se generan para las
próximas tres semanas a partir de hoy.

## Correr contra un backend

```bash
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8080
```

- `API_BASE_URL` es la dirección del backend. Por defecto es
  `http://localhost:8080`. Se lee en un único lugar:
  `lib/core/config/app_config.dart`.
- **Puerto web 5173.** `--web-port=5173` no es opcional: el backend tiene
  configurado ese origen en el CORS, y con otro puerto el navegador bloquea
  todas las respuestas.
- **Emulador de Android.** El emulador no llega al `localhost` de la
  computadora; la dirección del host es `10.0.2.2`:

  ```bash
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
  ```

## Rutas de la API

Todas las rutas están en `lib/core/network/api_routes.dart`; ningún repository
escribe una ruta literal. El registro de lo que se usa y su estado está en
`docs/api/endpoints-usados.md`.

## Verificación

```bash
flutter analyze
flutter test
```

## Cambiar el nombre de la mutualista

1. Editar la constante `kMutualistaName` en `lib/core/branding.dart`.
2. Correr `dart run tool/sync_nombre.dart` desde `frontend/`: reescribe
   `web/index.html`, `web/manifest.json`, `AndroidManifest.xml` y el título
   de este README.

El nombre técnico (`agenda_medica` en `pubspec.yaml` y el applicationId)
no se cambia.

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
