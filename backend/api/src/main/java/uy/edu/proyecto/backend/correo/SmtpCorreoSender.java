package uy.edu.proyecto.backend.correo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

/** SMTP para desarrollo local (Mailpit). Railway bloquea SMTP saliente en planes sin Pro. */
@Component
@ConditionalOnProperty(name = "app.mail.provider", havingValue = "smtp")
public class SmtpCorreoSender implements CorreoSender {

    private final JavaMailSender mailSender;
    private final String from;

    public SmtpCorreoSender(
            JavaMailSender mailSender,
            @Value("${app.email.from:}") String from
    ) {
        this.mailSender = mailSender;
        this.from = from;
    }

    @Override
    public void enviar(CorreoMensaje mensaje) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(mensaje.para());
        if (from != null && !from.isBlank()) {
            message.setFrom(from);
        }
        message.setSubject(mensaje.asunto());
        message.setText(mensaje.texto());

        try {
            mailSender.send(message);
        } catch (MailException exception) {
            throw new CorreoException(
                    "Fallo el envio SMTP: " + exception.getClass().getSimpleName()
            );
        }
    }
}
