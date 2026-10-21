package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

class PrimerIngresoMailListenerTest {

    private final JavaMailSender mailSender = mock(JavaMailSender.class);

    @Test
    void construyeCorreoConEnlaceDeUnSoloUsoYVencimiento() {
        PrimerIngresoMailListener listener = new PrimerIngresoMailListener(
                mailSender,
                "noreply@example.org",
                "https://app.example.org/primer-ingreso"
        );

        listener.enviarEnlace(new PrimerIngresoLinkSolicitado(
                12L,
                "ana@example.org",
                "Ana",
                "token-unico"
        ));

        ArgumentCaptor<SimpleMailMessage> message =
                ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mailSender).send(message.capture());
        assertTrue(message.getValue().getText().contains(
                "https://app.example.org/primer-ingreso?token=token-unico"
        ));
        assertTrue(message.getValue().getText().contains("vence en 24 horas"));
    }
}
