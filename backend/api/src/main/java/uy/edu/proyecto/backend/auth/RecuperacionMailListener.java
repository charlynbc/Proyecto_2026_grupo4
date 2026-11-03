package uy.edu.proyecto.backend.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

import uy.edu.proyecto.backend.correo.CorreoException;
import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;

/**
 * Correos de RF-05, despues del commit y en segundo plano, a traves del mismo
 * CorreoSender del primer ingreso. Nunca se envia una contrasena por correo.
 */
@Component
public class RecuperacionMailListener {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(RecuperacionMailListener.class);

    private final CorreoSender correoSender;
    private final String recuperacionUrl;

    public RecuperacionMailListener(
            CorreoSender correoSender,
            @Value("${app.email.recovery-url:http://localhost:5173/#/recuperacion}")
            String recuperacionUrl
    ) {
        this.correoSender = correoSender;
        this.recuperacionUrl = recuperacionUrl;
    }

    @Async
    @TransactionalEventListener
    public void enviarEnlace(RecuperacionLinkSolicitado event) {
        CorreoMensaje mensaje = new CorreoMensaje(
                event.correo(),
                "Recuperación de contraseña",
                "Hola " + event.nombre() + ":\n\n"
                        + "Recibimos un pedido para recuperar la contraseña de tu "
                        + "cuenta. Para definir una nueva, abrí este enlace:\n\n"
                        + recuperacionUrl + "?token=" + event.token()
                        + "\n\nEl enlace vence en " + event.validezHoras()
                        + " horas y solo puede usarse una vez.\n\n"
                        + "Si no pediste esto, ignorá este correo: tu contraseña "
                        + "actual no se modifica."
        );

        enviar(event.idCuenta(), mensaje);
    }

    @Async
    @TransactionalEventListener
    public void informarCuentaPendiente(
            CuentaPendienteRecuperacionSolicitada event
    ) {
        CorreoMensaje mensaje = new CorreoMensaje(
                event.correo(),
                "Tu cuenta todavía no está activada",
                "Hola " + event.nombre() + ":\n\n"
                        + "Recibimos un pedido de recuperación de contraseña, pero "
                        + "tu cuenta todavía no fue activada.\n\n"
                        + "Ingresá a la pantalla de acceso y usá la opción "
                        + "«Es mi primera vez» para activarla.\n\n"
                        + "Este correo no modifica tu cuenta."
        );

        enviar(event.idCuenta(), mensaje);
    }

    private void enviar(Long idCuenta, CorreoMensaje mensaje) {
        try {
            correoSender.enviar(mensaje);
        } catch (CorreoException exception) {
            // Los mensajes de CorreoException son propios (sin datos del correo).
            LOGGER.error(
                    "No se pudo enviar un correo de recuperacion para la cuenta {}: {}",
                    idCuenta,
                    exception.getMessage()
            );
        } catch (RuntimeException exception) {
            // Nunca se registra el contenido ni el destinatario del correo.
            LOGGER.error(
                    "No se pudo enviar un correo de recuperacion para la cuenta {}: {}",
                    idCuenta,
                    exception.getClass().getSimpleName()
            );
        }
    }
}
