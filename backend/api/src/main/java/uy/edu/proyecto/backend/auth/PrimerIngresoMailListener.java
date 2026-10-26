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
                        + "\n\nEl enlace vence en " + event.validezHoras()
                        + " horas y solo puede usarse una vez."
        );

        enviar(event.idCuenta(), mensaje);
    }

    @Async
    @TransactionalEventListener
    public void informarCuentaActiva(CuentaActivaPrimerIngresoSolicitada event) {
        CorreoMensaje mensaje = new CorreoMensaje(
                event.correo(),
                "Tu cuenta ya está activa",
                "Hola " + event.nombre() + ":\n\n"
                        + "Tu cuenta ya está activa. Para recuperar tu contraseña, "
                        + "ingresá a la pantalla de acceso correspondiente y seguí "
                        + "la opción de recuperación de contraseña (RF-05).\n\n"
                        + "Este correo no modifica tu contraseña ni el estado de tu cuenta."
        );

        enviar(event.idCuenta(), mensaje);
    }

    private void enviar(Long idCuenta, CorreoMensaje mensaje) {
        try {
            correoSender.enviar(mensaje);
        } catch (RuntimeException exception) {
            // Nunca se registra el contenido ni el destinatario del correo.
            LOGGER.error(
                    "No se pudo enviar un correo de primer ingreso para la cuenta {}: {}",
                    idCuenta,
                    exception.getClass().getSimpleName()
            );
        }
    }
}
