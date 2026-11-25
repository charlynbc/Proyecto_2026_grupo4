# Correo y despliegue en Railway

## Flujos de correo del backend

Hay tres flujos que envían correo, todos sobre la misma infraestructura
(`CorreoSender`, evento de dominio publicado dentro de la transacción y envío
**después del commit**, en segundo plano; el fallo del proveedor nunca cambia la
respuesta HTTP ni filtra la existencia de la cuenta):

| Flujo | RF | Tipo de enlace (`enlace_cuenta.tipo`) | Variable con la URL base |
|---|---|---|---|
| Primer ingreso | RF-02 | `PRIMER_INGRESO` | `FIRST_LOGIN_URL` |
| Recuperación de contraseña | RF-05 | `RECUPERACION` | `RECOVERY_URL` |
| Confirmación de cambio de correo | RF-06 | `CAMBIO_CORREO` | `CHANGE_EMAIL_URL` |

Los tres enlaces son aleatorios de 256 bits, se guardan solo como hash SHA-256,
vencen a las 24 horas y son de un solo uso; pedir uno nuevo invalida los
anteriores del mismo tipo (en RF-05 hay además un anti-reenvío de 60 segundos).
Nunca se envía una contraseña por correo y los logs no registran tokens,
destinatarios ni contenido.

## Primer ingreso (RF-02)

`PrimerIngresoService` genera el enlace (token aleatorio de 32 bytes, solo se
guarda su hash SHA-256, vence a las 24 horas, un solo uso, y pedir uno nuevo
invalida los anteriores). Publica `PrimerIngresoLinkSolicitado` y
`PrimerIngresoMailListener` lo envía **después del commit**, en segundo plano,
a través de la interfaz `CorreoSender`. La generación del enlace no conoce al
proveedor.

| `MAIL_PROVIDER` | Clase | Uso |
|---|---|---|
| `none` (por defecto) | `SinProveedorCorreoSender` | No envía; registra el fallo. El backend arranca igual. |
| `smtp` | `SmtpCorreoSender` | Desarrollo local con Mailpit. |
| `resend` | `ResendCorreoSender` | Railway (API HTTPS). |

Garantías: la respuesta de `solicitar` es siempre `202` con el mismo mensaje,
exista o no la cuenta. Los logs guardan el id de cuenta y, si falla el proveedor,
el motivo propio de `CorreoException` (por ejemplo `Resend respondio HTTP 403`);
nunca el token, el correo, el texto del mensaje ni la clave. No hay endpoints de
depuración. Si el proveedor falla, el pedido no falla (no se filtra la existencia
de la cuenta) y el fallo queda en el log.

### Enlace y ruta de Flutter

El correo contiene `FIRST_LOGIN_URL + "?token=<token>"`. Flutter web usa rutas
sin `#` y la pantalla está en `/primer-ingreso?token=`, por lo que el valor
correcto es `https://<host-del-frontend>/primer-ingreso`. El servidor Spring
responde el `index.html` en las rutas de la app (login, primer ingreso,
recuperación, cambio de correo, cuenta y los prefijos de cada rol: `/socio`,
`/funcionario`, `/medico` y `/admin`) sin pedir sesión; lo demás, por ejemplo
`/api/**`, no cambia.

### Orden de despliegue

Los tres enlaces de los correos (`FIRST_LOGIN_URL`, `RECOVERY_URL` y
`CHANGE_EMAIL_URL`) pasan de `…/#/ruta` a `…/ruta`. Para que ningún enlace
quede roto en el medio, el orden es este:

1. **Primero el backend con el fallback.** Con esa versión las rutas sin `#`
   ya responden el `index.html`. Las tres variables siguen con `#/` y los
   enlaces siguen funcionando con el frontend viejo.
2. **Después el frontend** con rutas sin `#`.
3. **Recién entonces, en Railway, cambiar las tres variables** a la forma sin
   `#/` (`https://<dominio-de-railway>/primer-ingreso`, `/recuperacion` y
   `/cambio-correo`) y reiniciar el servicio.

Los correos que ya salieron con `#/` valen hasta 24 horas (el vencimiento del
enlace). Con el frontend nuevo esos enlaces abren la pantalla de inicio de
sesión en vez de la que corresponde; conviene hacer el cambio en un momento de
poco movimiento o pedir un enlace nuevo si hace falta.

### Local con Mailpit

```bash
docker run -d --name mailpit -p 8025:8025 -p 1025:1025 axllent/mailpit
# .env: MAIL_PROVIDER=smtp  MAIL_HOST=localhost  MAIL_PORT=1025  MAIL_FROM=no-reply@mailpit.local
#       FIRST_LOGIN_URL=http://localhost:5173/primer-ingreso
```

La bandeja se ve en <http://localhost:8025>. Mailpit acepta cualquier destinatario y
no reenvía nada: no sale ningún correo real. Los tests automatizados usan
`MAIL_PROVIDER=none` y capturan el evento de dominio; nunca envían correo.

Prueba de punta a punta (datos ficticios, base local descartable):

```powershell
# 1. Cuentas pendientes ficticias (solo INSERT; no hace TRUNCATE)
docker exec -i <postgres> psql -U postgres -d <base> -v ON_ERROR_STOP=1 < database/pruebas/datos_primer_ingreso_local.sql
# 2. Backend con SMTP a Mailpit, y luego:
powershell -ExecutionPolicy Bypass -File scripts/probar-primer-ingreso-mailpit.ps1 -BaseUrl http://localhost:8080 -Ci 40000018 -Acceso SOCIO
powershell -ExecutionPolicy Bypass -File scripts/probar-primer-ingreso-mailpit.ps1 -BaseUrl http://localhost:8080 -Ci 40000024 -Acceso EMPLEADO
```

El script distingue cada etapa: solicitud HTTP aceptada (202), correo recibido en
Mailpit, enlace con la forma `…/primer-ingreso?token=…`, cuenta activada, enlace
reutilizado rechazado y login satisfactorio. Nunca imprime el token completo.
Para hacerlo desde la interfaz: abrir el enlace del correo en Flutter web
(`/primer-ingreso?token=…`), completar el formulario y entrar por el login.

## Railway (desarrollo)

Railway **bloquea SMTP saliente** en los planes Free, Trial y Hobby (solo Pro
y superiores lo permiten), así que se usa `MAIL_PROVIDER=resend` (HTTPS).
Verificar el plan vigente en la documentación de Railway antes de la demo.

Variables (los valores secretos se cargan en el panel de Railway, nunca en Git):

| Variable | Obligatoria | Descripción |
|---|---|---|
| `PORT` | la define Railway | Puerto de escucha (`server.port=${PORT:8080}`). |
| `DB_URL`, `DB_USER`, `DB_PASSWORD` | sí | PostgreSQL del entorno. No usar las bases compartidas de Supabase para pruebas. |
| `JWT_SECRET_BASE64` | sí | Clave HS256, 32 bytes o más en base64. |
| `CORS_ALLOWED_ORIGIN` | sí | Origen exacto del frontend (`https://...`, sin barra final). Aunque web y API compartan dominio, debe estar. |
| `COOKIE_SECURE` | sí | `true` (HTTPS). |
| `COOKIE_SAME_SITE` | sí | `Lax` (la web se sirve desde el mismo dominio que la API). Solo `None` si algún día el frontend queda en otro sitio. |
| `APP_FIREBASE_ENABLED` | sí | `true` para activar los avisos push; `false` si no hay credenciales de Firebase. Con `true` y sin credenciales el servicio no arranca. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | solo con push | Clave de la cuenta de servicio de Firebase: el contenido del JSON o ese mismo JSON en base64 (recomendado en Railway, que no monta archivos). Es secreta: se carga solo en el panel de Railway, nunca en Git. Si está vacía se usa `GOOGLE_APPLICATION_CREDENTIALS`. |
| `GOOGLE_APPLICATION_CREDENTIALS` | alternativa | Ruta a un archivo JSON con la clave de la cuenta de servicio. Sirve en una máquina propia; en Railway no, porque no hay dónde dejar el archivo. Solo se mira si `FIREBASE_SERVICE_ACCOUNT_JSON` está ausente o vacía. |
| `MAIL_PROVIDER` | sí | `resend`. |
| `RESEND_API_KEY` | sí | Clave de la cuenta de Resend. |
| `MAIL_FROM` | sí | Remitente verificado en Resend (por ejemplo `Clínica <no-reply@dominio>`). |
| `FIRST_LOGIN_URL` | sí | `https://<dominio-de-railway>/primer-ingreso` (sin `?token=`). Cambiarla después de desplegar backend y frontend nuevos (ver "Orden de despliegue"). |
| `RECOVERY_URL` | sí | `https://<dominio-de-railway>/recuperacion` (sin `?token=`). Mismo orden de despliegue. |
| `CHANGE_EMAIL_URL` | sí | `https://<dominio-de-railway>/cambio-correo` (sin `?token=`). Mismo orden de despliegue. |

Clave de Firebase para los avisos push. Se descarga de la consola de Firebase (configuración del
proyecto, cuentas de servicio, generar clave privada). Es secreta: nunca va al repositorio ni a una
captura, y si se expone hay que revocarla y generar otra. Para cargarla en Railway como base64:

```powershell
# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\ruta\al\archivo.json"))
```

```bash
# macOS (copia el resultado al portapapeles)
base64 -i clave.json | pbcopy
# Linux (una sola línea)
base64 -w0 clave.json
```

Se pega el resultado como valor de `FIREBASE_SERVICE_ACCOUNT_JSON` y se pone
`APP_FIREBASE_ENABLED=true`. Si el valor no es un JSON ni un base64 válido, el servicio no arranca y el
mensaje lo dice sin mostrar el valor cargado.

Procesos programados de avisos. Tiene valor por defecto: solo hace falta cargarla para apagarlos.

| Variable | Obligatoria | Por defecto | Descripción |
|---|---|---|---|
| `NOTIFICACIONES_PROCESOS_PROGRAMADOS_HABILITADOS` | no | `true` | Con `false` no corre el poller programado de envíos (ni lo hará el futuro job de recordatorios). El envío que se hace al crear la notificación no cambia. **El servicio `backend-dev` debe tener `false`**: `backend` y `backend-dev` comparten la base de pruebas, y el poller de dev marca como `FALLIDO` los envíos que agarra del otro. |

Parámetros de negocio (RNF-26). **Todos tienen valor por defecto** (el definido en la sección 3.1.3
de Requerimientos): solo hace falta cargarlos en Railway para usar un valor distinto. Los lee un único
componente al arrancar; un valor inválido (no entero, cero o negativo, un mínimo mayor que su máximo, un
paso que no divide el rango) impide que el servicio arranque y el log nombra la variable. Un cambio se
aplica al reiniciar el servicio, sin reconstruirlo.

| Variable | Obligatoria | Por defecto | Descripción |
|---|---|---|---|
| `PARAM_AGENDAR_ANTICIPACION_MAXIMA_DIAS` | no | 30 | Anticipación máxima para agendar, en días. |
| `PARAM_AGENDAR_ANTICIPACION_MINIMA_HORAS` | no | 2 | Anticipación mínima para agendar, en horas. |
| `PARAM_CANCELAR_ANTICIPACION_MINIMA_HORAS` | no | 2 | Anticipación mínima para cancelar, en horas. |
| `PARAM_CONSULTAS_ACTIVAS_POR_ESPECIALIDAD` | no | 1 | Consultas activas por socio en una especialidad. |
| `PARAM_CONSULTAS_ACTIVAS_TOTAL` | no | 3 | Consultas activas por socio en total. |
| `PARAM_NUMERO_DURACION_MINIMA_MINUTOS` | no | 10 | Duración mínima de un número, en minutos. |
| `PARAM_NUMERO_DURACION_MAXIMA_MINUTOS` | no | 60 | Duración máxima de un número, en minutos. |
| `PARAM_NUMERO_DURACION_PASO_MINUTOS` | no | 5 | Paso de la duración y de los horarios de un número, en minutos. |
| `PARAM_PASE_VIGENCIA_INICIAL_DIAS` | no | 90 | Vigencia de un pase si el médico no indica otra, en días. |
| `PARAM_PASE_VIGENCIA_MINIMA_DIAS` | no | 1 | Vigencia mínima que el médico puede fijar, en días. |
| `PARAM_PASE_VIGENCIA_MAXIMA_DIAS` | no | 365 | Vigencia máxima que el médico puede fijar, en días. |
| `PARAM_RECORDATORIO_ANTELACION_HORAS` | no | 24 | Antelación del recordatorio de consulta, en horas. Se lee y valida, pero ningún envío la usa todavía. |
| `PASSWORD_MIN_LENGTH` | no | 8 | Largo mínimo de la contraseña. |
| `FIRST_LOGIN_TOKEN_VALIDITY_HOURS` | no | 24 | Vigencia del enlace de primer ingreso, en horas. |
| `RECOVERY_TOKEN_VALIDITY_HOURS` | no | 24 | Vigencia del enlace de recuperación de contraseña, en horas. |
| `EMAIL_CHANGE_TOKEN_VALIDITY_HOURS` | no | 24 | Vigencia del enlace de cambio de correo, en horas. |

Las pantallas del frontend que avisan "vale 24 horas" usan texto fijo: si se cambia una de las tres
vigencias de enlaces hay que cambiar también ese texto (ver `.env.example`).

Detrás del proxy de Railway se activa `server.forward-headers-strategy=framework`
para respetar HTTPS. Si `MAIL_PROVIDER` queda en `none`, el backend sube pero los
correos de primer ingreso no salen (aviso al arrancar y un error en el log por cada pedido).

### Qué depende de quien administra Railway/Resend

El código está listo, pero **no se verificó ninguna entrega remota**: falta lo siguiente
y no se configuró nada externo desde el repositorio.

1. Cuenta de Resend con una **API key** (cargarla solo como `RESEND_API_KEY` en el panel).
2. **Dominio verificado en Resend** (registros DNS SPF/DKIM) y un `MAIL_FROM` de ese
   dominio. Sin dominio verificado, Resend solo permite enviar desde su remitente de
   pruebas (`onboarding@resend.dev`) y únicamente al correo del titular de la cuenta.
3. Cargar en el servicio de **desarrollo** (nunca el de producción) las variables de la tabla.
4. Una **dirección de prueba controlada por el equipo** para recibir el correo real.
5. Autorización para redesplegar ese servicio.

Verificación remota (cuando 1 a 5 estén listos), con una cuenta pendiente ficticia
cuyo correo sea el buzón de prueba del equipo:

1. `POST /api/auth/primer-ingreso/solicitar` → `202` (solo prueba que el pedido llegó).
2. Log del backend sin `No se pudo enviar un correo…` (el proveedor aceptó el envío) y el
   panel de Resend con el correo en estado *delivered*.
3. El correo está en el buzón de prueba; el enlace empieza con `FIRST_LOGIN_URL?token=`.
4. Abrir el enlace, completar el formulario y comprobar que redirige al login.
5. Iniciar sesión con la contraseña nueva.

Un `202` no demuestra nada más que el punto 1.

### Verificación remota de RF-05 y RF-06 (mismo criterio)

Con la cuenta ya activada del buzón de prueba:

1. `POST /api/auth/recuperacion/solicitar` con su CI y acceso → `202`.
2. Panel de Resend con el correo *delivered*; el enlace empieza con
   `RECOVERY_URL?token=`.
3. Abrir el enlace, definir la contraseña nueva con
   `POST /api/auth/recuperacion/completar` → `200`, e iniciar sesión con ella.
4. Para RF-06: iniciar sesión, `PATCH /api/cuentas/me` con un `correo` del
   buzón de prueba → `200` con `correoPendiente`; el correo llega al correo
   **nuevo**; abrir el enlace (`CHANGE_EMAIL_URL?token=`) y confirmar con
   `POST /api/auth/cambio-correo/confirmar` → `200`; `GET /api/cuentas/me`
   muestra el correo nuevo.

**Estado al 01/11/2026:** RF-05 y RF-06 se probaron con el proveedor simulado
(captura del evento de dominio en las pruebas de integración) y el patrón de
envío es el mismo que RF-02, pero **no se verificó ninguna entrega remota
real**: falta la misma configuración de Resend descrita arriba.

### Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| `202` pero no llega nada y el log dice `MAIL_PROVIDER=none` | Falta configurar el proveedor. |
| Log: `Falta RESEND_API_KEY` / `Falta MAIL_FROM` | Variable ausente en Railway. |
| Log: `Resend respondio HTTP 403` | Dominio de `MAIL_FROM` no verificado, o clave sin permiso. |
| Log: `Resend respondio HTTP 422` | `MAIL_FROM` con formato inválido o destinatario inválido. |
| Log: `Resend respondio HTTP 401` | `RESEND_API_KEY` incorrecta o revocada. |
| Log: `Fallo el envio SMTP` en Railway | SMTP saliente bloqueado: usar `resend`. |
| El enlace abre la pantalla de login o de solicitud | `FIRST_LOGIN_URL` apuntando a otra ruta, o con `#/` cuando el frontend ya usa rutas sin `#` (o al revés, sin `#/` con el frontend viejo). |
| El login falla con «Invalid CORS request» | `CORS_ALLOWED_ORIGIN` no coincide exactamente con el origen del navegador. |
| La sesión no se mantiene en HTTPS | `COOKIE_SECURE=false` o `COOKIE_SAME_SITE` inadecuado. |
| «El enlace ya no es válido» | Venció (24 h), ya se usó, se pidió uno más nuevo o la cuenta fue inactivada. |

## Avisos push en Android: canal, prioridad y vigencia

Cada aviso push que el backend manda por Firebase Cloud Messaging lleva una
configuración para Android (`AndroidConfig`):

| Dato | Valor |
|---|---|
| Canal de notificaciones | `avisos_consultas`, el mismo para todos los tipos |
| Prioridad | alta, para todos los tipos (también uno desconocido) |
| Vigencia (TTL), recordatorio de consulta | 2 horas |
| Vigencia (TTL), agenda, cancelación, suspensión y historia clínica actualizada | 7 días |

La vigencia es cuánto tiempo guarda FCM el aviso si el celular está apagado o
sin conexión: pasado ese tiempo se descarta y no se entrega. El recordatorio
dura poco porque deja de servir cuando empieza la consulta. Se programa con la
antelación que define `PARAM_RECORDATORIO_ANTELACION_HORAS` (24 por defecto),
así que con el valor por defecto sale mucho antes de la consulta. Con una
antelación menor que 2 horas, un recordatorio retenido podría entregarse hasta 2
horas después de enviado, ya empezada la consulta.

### La app tiene que crear el canal

El backend solo manda el id del canal: el canal lo crea la app en el celular. El
frontend debe crear un canal de notificaciones con el id exacto `avisos_consultas`
(lo hace el PR de frontend que sigue a este). Si el id cambia en el backend
(`PoliticaAndroidAviso.CANAL_AVISOS`), tiene que cambiar también en la app.

Mientras el canal no exista en la app, Android no muestra el aviso en ese canal:
según la documentación de FCM usa el canal por defecto que declara el manifiesto
de la app o, si no hay, el genérico. Cuál de los dos ocurre en esta app se
confirma en la prueba de punta a punta con un celular real.

### Dispositivos que ya no existen

Si FCM responde que el token ya no está registrado (`UNREGISTERED`: la app se
desinstaló o el token venció), el envío queda `FALLIDO` y el dispositivo se
deshabilita (`dispositivo_push.habilitado = false`) para no seguir mandándole
avisos. Cuando el socio inicia sesión de nuevo en la app, el registro del token
lo vuelve a habilitar. Cualquier otro rechazo de FCM (por ejemplo
`INVALID_ARGUMENT` o cuota excedida) deja el envío `FALLIDO` sin tocar el
dispositivo. El log avisa con el id del envío y el tipo, nunca con el token.

### `google-services.json` en el build de Android

El APK solo tiene avisos push si se compila con
`frontend/android/app/google-services.json`, que se descarga de la consola de
Firebase. El archivo está en `.gitignore` y no se versiona: cada integrante lo
pone a mano en esa carpeta. Un APK compilado sin él funciona, pero no tiene push
y no avisa que falta.

## Enlaces de la aplicación Android (App Links)

Para que, en un celular con la app instalada, los enlaces de los correos
(`/primer-ingreso`, `/recuperacion` y `/cambio-correo`) abran la app y no el
navegador, Android tiene que verificar que el dominio pertenece a la app. Esa
verificación lee el archivo `https://<dominio>/.well-known/assetlinks.json`.

### Qué hace el servidor

El backend responde `GET /.well-known/assetlinks.json` sin sesión, con
`Content-Type: application/json` y sin redirecciones. El cuerpo es una lista con
una sola declaración (paquete de la app y huellas SHA-256 de su certificado de
firma). Sin ninguna huella válida responde `200` con la lista vacía `[]`. Las
huellas son públicas: no son un secreto.

| Variable | Obligatoria | Descripción |
|---|---|---|
| `ANDROID_APP_PACKAGE_NAME` | no | Paquete de la app. Por defecto `uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica`. |
| `ANDROID_APP_FINGERPRINTS` | sí en producción | Huellas SHA-256 separadas por comas, por ejemplo `01:AC:05:8D:AC:C7:69:7C:34:98:6D:2D:8A:68:D6:D7:51:F7:F4:B3:0C:69:CB:11:0C:0C:88:8D:23:20:4F:0C`. Cada una son 32 pares hexadecimales separados por dos puntos. Las que no tienen ese formato se descartan y el log avisa cuántas fueron (sin mostrarlas). Por defecto lleva la huella de la clave debug del equipo. |

Agregar una huella no necesita recompilar: se cambia la variable y se reinicia
el servicio.

### Qué tiene que estar listo antes de instalar la app

1. El dominio `medicaoriental.vip` tiene que apuntar al servicio de Railway.
2. `https://medicaoriental.vip/.well-known/assetlinks.json` tiene que responder
   `200` por HTTPS, sin redirecciones, con la huella de la clave con que se
   firmó la app.

### Orden

1. Desplegar el backend con este endpoint y comprobar el archivo en el
   navegador o con `curl -i https://medicaoriental.vip/.well-known/assetlinks.json`.
2. Instalar la app Android firmada con la clave cuya huella figura en
   `ANDROID_APP_FINGERPRINTS`.
3. Recién entonces probar los enlaces de los correos.

Android verifica el dominio cuando se instala la app. Si en ese momento el
archivo no estaba disponible, la verificación falla y los enlaces abren el
navegador: hay que reinstalar la app o pedir la verificación de nuevo:

```
adb shell pm verify-app-links --re-verify uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica
adb shell pm get-app-links uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica
```

El segundo comando debe mostrar el dominio como `verified`.

### Otra clave de firma

La huella por defecto es la de una sola máquina. Quien compile la app con otra
clave debug tiene que agregar su huella a `ANDROID_APP_FINGERPRINTS`. Se obtiene
con el siguiente comando, y se copia solo la línea `SHA256`:

```
keytool -list -v -keystore <ruta-de-su-debug.keystore> -alias androiddebugkey
```

Para publicar en Google Play hay que agregar también la huella de la clave de
Play App Signing (consola de Play, Integridad de la aplicación). Es otra
huella, distinta de la de debug.
