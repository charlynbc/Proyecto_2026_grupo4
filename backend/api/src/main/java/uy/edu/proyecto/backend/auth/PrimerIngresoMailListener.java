package uy.edu.proyecto.backend.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class PrimerIngresoMailListener {

    private static final Logger LOGGER =
            LoggerFactory.getLogger(PrimerIngresoMailListener.class);

    private final JavaMailSender mailSender;
    private final String from;
    private final String activationUrl;

    public PrimerIngresoMailListener(
            JavaMailSender mailSender,
            @Value("${app.email.from:}") String from,
            @Value("${app.email.first-login-url:http://localhost:5173/primer-ingreso}")
            String activationUrl
    ) {
        this.mailSender = mailSender;
        this.from = from;
        this.activationUrl = activationUrl;
    }

    @Async
    @TransactionalEventListener
    public void enviarEnlace(PrimerIngresoLinkSolicitado event) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(event.correo());
        if (!from.isBlank()) {
            message.setFrom(from);
        }
        message.setSubject("Activacion de cuenta");
        message.setText(
                "Hola " + event.nombre() + ":\n\n"
                        + "Para completar tu primer ingreso, abre este enlace:\n\n"
                        + activationUrl + "?token=" + event.token()
                        + "\n\nEl enlace vence en 24 horas."
        );

        try {
            mailSender.send(message);
        } catch (MailException exception) {
            LOGGER.error(
                    "No se pudo enviar el enlace de primer ingreso para la cuenta {}",
                    event.idCuenta(),
                    exception
            );
        }
    }
}
