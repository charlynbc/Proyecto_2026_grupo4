# Correo y despliegue en Railway

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

El correo contiene `FIRST_LOGIN_URL + "?token=<token>"`. Flutter web usa la
estrategia de URL con `#`, y la pantalla está en `/primer-ingreso?token=`, por
lo que el valor correcto es `https://<host-del-frontend>/#/primer-ingreso`.
Si el equipo cambia a URLs sin `#`, quitar el `#/`.

### Local con Mailpit

```bash
docker run -d --name mailpit -p 8025:8025 -p 1025:1025 axllent/mailpit
# .env: MAIL_PROVIDER=smtp  MAIL_HOST=localhost  MAIL_PORT=1025  MAIL_FROM=no-reply@mailpit.local
#       FIRST_LOGIN_URL=http://localhost:5173/#/primer-ingreso
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
Mailpit, enlace con la forma `…/#/primer-ingreso?token=…`, cuenta activada, enlace
reutilizado rechazado y login satisfactorio. Nunca imprime el token completo.
Para hacerlo desde la interfaz: abrir el enlace del correo en Flutter web
(`/#/primer-ingreso?token=…`), completar el formulario y entrar por el login.

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
| `APP_FIREBASE_ENABLED` | sí | `false` salvo que haya credenciales de Firebase. |
| `MAIL_PROVIDER` | sí | `resend`. |
| `RESEND_API_KEY` | sí | Clave de la cuenta de Resend. |
| `MAIL_FROM` | sí | Remitente verificado en Resend (por ejemplo `Clínica <no-reply@dominio>`). |
| `FIRST_LOGIN_URL` | sí | `https://<dominio-de-railway>/#/primer-ingreso` (sin `?token=`). |
| `PASSWORD_MIN_LENGTH` | no | Por defecto 8. |

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

### Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| `202` pero no llega nada y el log dice `MAIL_PROVIDER=none` | Falta configurar el proveedor. |
| Log: `Falta RESEND_API_KEY` / `Falta MAIL_FROM` | Variable ausente en Railway. |
| Log: `Resend respondio HTTP 403` | Dominio de `MAIL_FROM` no verificado, o clave sin permiso. |
| Log: `Resend respondio HTTP 422` | `MAIL_FROM` con formato inválido o destinatario inválido. |
| Log: `Resend respondio HTTP 401` | `RESEND_API_KEY` incorrecta o revocada. |
| Log: `Fallo el envio SMTP` en Railway | SMTP saliente bloqueado: usar `resend`. |
| El enlace abre la pantalla de login o de solicitud | `FIRST_LOGIN_URL` sin `#/` o apuntando a otra ruta. |
| El login falla con «Invalid CORS request» | `CORS_ALLOWED_ORIGIN` no coincide exactamente con el origen del navegador. |
| La sesión no se mantiene en HTTPS | `COOKIE_SECURE=false` o `COOKIE_SAME_SITE` inadecuado. |
| «El enlace ya no es válido» | Venció (24 h), ya se usó, se pidió uno más nuevo o la cuenta fue inactivada. |
