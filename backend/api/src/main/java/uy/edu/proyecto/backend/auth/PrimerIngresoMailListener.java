package uy.edu.proyecto.backend.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;

@Component
public class PrimerIngresoMailListener {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(PrimerIngresoMailListener.class);

    private final CorreoSender correoSender;
    private final String activationUrl;

    public PrimerIngresoMailListener(
            CorreoSender correoSender,
            @Value("${app.email.first-login-url:http://localhost:5173/#/primer-ingreso}")
            String activationUrl
    ) {
        this.correoSender = correoSender;
        this.activationUrl = activationUrl;
    }

    @Async
    @TransactionalEventListener
    public void enviarEnlace(PrimerIngresoLinkSolicitado event) {
        CorreoMensaje mensaje = new CorreoMensaje(
                event.correo(),
                "Activacion de cuenta",
                "Hola " + event.nombre() + ":\n\n"
                        + "Para completar tu primer ingreso, abre este enlace:\n\n"
                        + activationUrl + "?token=" + event.token()
                        + "\n\nEl enlace vence en 24 horas y solo puede usarse una vez."
        );

        try {
            correoSender.enviar(mensaje);
        } catch (RuntimeException exception) {
            // Nunca se registra el token ni el correo: solo la cuenta y el tipo de fallo.
            LOGGER.error(
                    "No se pudo enviar el enlace de primer ingreso para la cuenta {}: {}",
                    event.idCuenta(),
                    exception.getClass().getSimpleName()
            );
        }
    }
}
