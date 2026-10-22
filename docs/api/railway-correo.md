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
exista o no la cuenta. Los logs solo guardan el id de cuenta y la clase del
error; nunca el token, el correo ni la clave. No hay endpoints de depuración.
Si el proveedor falla, el pedido no falla (no se filtra la existencia de la
cuenta) y el fallo queda en el log.

### Enlace y ruta de Flutter

El correo contiene `FIRST_LOGIN_URL + "?token=<token>"`. Flutter web usa la
estrategia de URL con `#`, y la pantalla está en `/primer-ingreso?token=`, por
lo que el valor correcto es `https://<host-del-frontend>/#/primer-ingreso`.
Si el equipo cambia a URLs sin `#`, quitar el `#/`.

### Local con Mailpit

```bash
docker run -d -p 8025:8025 -p 1025:1025 axllent/mailpit
# .env: MAIL_PROVIDER=smtp  MAIL_HOST=localhost  MAIL_PORT=1025
```

La bandeja se ve en <http://localhost:8025>. No se envía nada a destinatarios reales.

## Railway

Railway **bloquea SMTP saliente** en los planes Free, Trial y Hobby (solo Pro
y superiores lo permiten), así que se usa `MAIL_PROVIDER=resend` (HTTPS).
Verificar el plan vigente en la documentación de Railway antes de la demo.

Variables (los valores secretos se cargan en el panel de Railway, nunca en Git):

| Variable | Obligatoria | Descripción |
|---|---|---|
| `PORT` | la define Railway | Puerto de escucha (`server.port=${PORT:8080}`). |
| `DB_URL`, `DB_USER`, `DB_PASSWORD` | sí | PostgreSQL del entorno. No usar las bases compartidas de Supabase para pruebas. |
| `JWT_SECRET_BASE64` | sí | Clave HS256, 32 bytes o más en base64. |
| `CORS_ALLOWED_ORIGIN` | sí | Origen exacto del frontend (`https://...`, sin barra final). |
| `COOKIE_SECURE` | sí | `true` (HTTPS). |
| `COOKIE_SAME_SITE` | sí | `None` si el frontend está en otro dominio; `Lax` si comparten sitio. |
| `APP_FIREBASE_ENABLED` | sí | `false` salvo que haya credenciales de Firebase. |
| `MAIL_PROVIDER` | sí | `resend`. |
| `RESEND_API_KEY` | sí | Clave de la cuenta de Resend. |
| `MAIL_FROM` | sí | Remitente verificado en Resend (por ejemplo `Clínica <no-reply@dominio>`). |
| `FIRST_LOGIN_URL` | sí | URL del frontend, ver arriba. |
| `PASSWORD_MIN_LENGTH` | no | Por defecto 8. |

Detrás del proxy de Railway se activa `server.forward-headers-strategy=framework`
para respetar HTTPS. Si `MAIL_PROVIDER` queda en `none`, el backend sube pero los
correos de primer ingreso no salen (queda un error en el log por cada pedido).
