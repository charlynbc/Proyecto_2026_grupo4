package uy.edu.proyecto.backend.usuario;

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
 * Envia el enlace de confirmacion de cambio de correo (RF-06) al correo NUEVO,
 * despues del commit y en segundo plano, como hace el primer ingreso (RF-02).
 */
@Component
public class CambioCorreoMailListener {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(CambioCorreoMailListener.class);

    private final CorreoSender correoSender;
    private final String cambioCorreoUrl;

    public CambioCorreoMailListener(
            CorreoSender correoSender,
            @Value("${app.email.change-email-url:http://localhost:5173/#/cambio-correo}")
            String cambioCorreoUrl
    ) {
        this.correoSender = correoSender;
        this.cambioCorreoUrl = cambioCorreoUrl;
    }

    @Async
    @TransactionalEventListener
    public void enviarEnlace(CambioCorreoSolicitado event) {
        CorreoMensaje mensaje = new CorreoMensaje(
                event.correoNuevo(),
                "Confirmá tu nuevo correo",
                "Hola " + event.nombre() + ":\n\n"
                        + "Pediste cambiar el correo de tu cuenta por esta dirección.\n"
                        + "Para confirmarlo, abrí este enlace:\n\n"
                        + cambioCorreoUrl + "?token=" + event.token()
                        + "\n\nEl enlace vence en " + event.validezHoras()
                        + " horas y solo puede usarse una vez.\n\n"
                        + "Si no pediste este cambio, ignorá este correo: "
                        + "tu dirección actual no se modifica."
        );

        try {
            correoSender.enviar(mensaje);
        } catch (CorreoException exception) {
            // Los mensajes de CorreoException son propios (sin datos del correo).
            LOGGER.error(
                    "No se pudo enviar un correo de cambio de correo para la cuenta {}: {}",
                    event.idCuenta(),
                    exception.getMessage()
            );
        } catch (RuntimeException exception) {
            // Nunca se registra el contenido ni el destinatario del correo.
            LOGGER.error(
                    "No se pudo enviar un correo de cambio de correo para la cuenta {}: {}",
                    event.idCuenta(),
                    exception.getClass().getSimpleName()
            );
        }
    }
}
