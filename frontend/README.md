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
mismo. Para activar una cuenta abrí `/primer-ingreso?token=cualquiera`; los
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

## Pantallas nuevas y la barra de botones de Android

Desde Android 15 la app se dibuja de borde a borde y un `Scaffold` sin
`bottomNavigationBar` no deja margen abajo: el contenido queda detrás de la
barra de botones del sistema. Una pantalla nueva que se muestre **sin barra
inferior propia** (una ruta de nivel superior en `lib/core/router/app_router.dart`)
tiene que envolverse en `BottomSystemInset` (`lib/core/widgets/bottom_system_inset.dart`).
Las secciones que muestran la barra `AdaptiveNavBar` no lo necesitan: la barra ya
reserva ese espacio, y usarlo también lo duplicaría.

## Enlaces de correo en Android (App Links)

El manifiesto (`android/app/src/main/AndroidManifest.xml`) tiene, además del
filtro de arranque, un filtro con `android:autoVerify="true"` para los enlaces
`https://medicaoriental.vip/primer-ingreso`, `/recuperacion` y `/cambio-correo`.
En un celular con la app instalada, abrir uno de esos enlaces desde el correo
abre la app en esa pantalla, con el `token` de la dirección, y no el navegador.
El host es fijo en el manifiesto: tiene que ser el mismo que usan las variables
`FIRST_LOGIN_URL`, `RECOVERY_URL` y `CHANGE_EMAIL_URL` del backend.

Para que Android confíe en el dominio, el backend publica
`https://medicaoriental.vip/.well-known/assetlinks.json` con la huella SHA-256
del certificado con que se firmó la APK. Esa huella tiene que estar en la
variable `ANDROID_APP_FINGERPRINTS` del backend. La APK de debug y la de
release se firman hoy con la misma clave debug del equipo; quien compile con
otra clave debe agregar su huella (`keytool -list -v` sobre su
`debug.keystore`).

### adb de esta máquina

Usar siempre el adb del SDK de Android:
`C:\Users\leona\AppData\Local\Android\Sdk\platform-tools\adb.exe`. En esta
máquina `ANDROID_HOME` está vacío y el adb que aparece primero en el `PATH` es
otra versión (la de scrcpy). Mezclar las dos reinicia el servidor de adb y corta
la conexión con el celular.

### Probar sin esperar el despliegue

1. Con el celular conectado, correr la app con datos de prueba:
   `flutter run --dart-define=USE_FAKES=true`. Con `USE_FAKES=true` sirve
   cualquier token para el primer ingreso, salvo `vencido`, `usado` y el vacío.
2. En otra terminal de PowerShell, abrir el enlace indicando el paquete al final.
   Con el paquete, Android entrega el enlace a la app aunque el dominio todavía
   no esté verificado:

```powershell
& "C:\Users\leona\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell am start -a android.intent.action.VIEW -d "https://medicaoriental.vip/primer-ingreso?token=cualquiera" uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica
```

La app tiene que abrir la pantalla de primer ingreso con ese token, tanto con la
app cerrada como abierta. Las otras dos rutas se prueban igual con
`/recuperacion?token=cualquiera` y `/cambio-correo?token=cualquiera`.

### Verificar el dominio una vez desplegado

Con el backend desplegado y la app instalada (Android verifica el dominio al
instalar):

```powershell
& "C:\Users\leona\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell pm get-app-links uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica
```

`medicaoriental.vip` debe figurar como `verified`. Si figura de otra forma, por
ejemplo porque el archivo no estaba disponible al instalar, se fuerza otra
verificación y se vuelve a consultar:

```powershell
& "C:\Users\leona\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell pm verify-app-links --re-verify uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica
```

Si sigue sin verificarse, revisar que el archivo responda `200` por HTTPS sin
redirecciones y que la huella de la APK esté en `ANDROID_APP_FINGERPRINTS`.

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

## Regenerar los íconos

Los íconos de web (`web/favicon.png` y `web/icons/`) y de Android
(`ic_launcher.png` e `ic_launcher_foreground.png` en cada `mipmap-*`) salen
de `assets/images/logo.svg`. Desde `frontend/`:

```
flutter test tool/generar_iconos.dart
```

El script no se corre con `flutter test` a secas. Las constantes que se
ajustan están arriba de `tool/generar_iconos.dart`: el color hueso de fondo,
el porcentaje que ocupa el logo en cada tipo de ícono y los tamaños. Dos
corridas dejan los mismos archivos. Los XML del ícono adaptativo de Android
(`mipmap-anydpi-v26/ic_launcher.xml` y `values/ic_launcher_background.xml`)
se editan a mano: si cambia el hueso, hay que cambiarlo también en `values`.

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
