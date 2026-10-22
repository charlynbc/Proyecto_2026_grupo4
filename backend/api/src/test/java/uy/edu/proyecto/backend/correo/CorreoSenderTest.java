package uy.edu.proyecto.backend.correo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

import com.sun.net.httpserver.HttpServer;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

class CorreoSenderTest {

    private static final CorreoMensaje MENSAJE = new CorreoMensaje(
            "ana@example.org",
            "Activacion de cuenta",
            "enlace?token=secreto-1"
    );

    @Test
    void smtpEnviaElMensajeAlDestinatario() {
        JavaMailSender mailSender = mock(JavaMailSender.class);

        new SmtpCorreoSender(mailSender, "no-reply@example.org").enviar(MENSAJE);

        ArgumentCaptor<SimpleMailMessage> enviado =
                ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mailSender).send(enviado.capture());
        assertEquals("ana@example.org", enviado.getValue().getTo()[0]);
        assertEquals("no-reply@example.org", enviado.getValue().getFrom());
    }

    @Test
    void smtpTraduceFallosSinFiltrarContenido() {
        JavaMailSender mailSender = mock(JavaMailSender.class);
        doThrow(new MailSendException("fallo ana@example.org secreto-1"))
                .when(mailSender).send(any(SimpleMailMessage.class));

        CorreoException error = assertThrows(
                CorreoException.class,
                () -> new SmtpCorreoSender(mailSender, "").enviar(MENSAJE)
        );

        assertFalse(error.getMessage().contains("secreto-1"));
        assertFalse(error.getMessage().contains("ana@example.org"));
    }

    @Test
    void sinProveedorFallaEnVezDeSimularExito() {
        assertThrows(
                CorreoException.class,
                () -> new SinProveedorCorreoSender().enviar(MENSAJE)
        );
    }

    @Test
    void resendExigeClaveDeApi() {
        ResendCorreoSender sender =
                new ResendCorreoSender("https://api.resend.com", "", "no-reply@example.org");

        CorreoException error =
                assertThrows(CorreoException.class, () -> sender.enviar(MENSAJE));

        assertEquals("Falta RESEND_API_KEY", error.getMessage());
    }

    @Test
    void resendPublicaPorHttpsApiConBearerYCuerpoEsperado() throws IOException {
        AtomicReference<String> autorizacion = new AtomicReference<>();
        AtomicReference<String> cuerpo = new AtomicReference<>();
        HttpServer servidor = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        servidor.createContext("/emails", exchange -> {
            autorizacion.set(exchange.getRequestHeaders().getFirst("Authorization"));
            cuerpo.set(new String(
                    exchange.getRequestBody().readAllBytes(),
                    StandardCharsets.UTF_8
            ));
            exchange.sendResponseHeaders(200, -1);
            exchange.close();
        });
        servidor.start();
        try {
            new ResendCorreoSender(
                    "http://127.0.0.1:" + servidor.getAddress().getPort(),
                    "clave-de-prueba",
                    "no-reply@example.org"
            ).enviar(MENSAJE);
        } finally {
            servidor.stop(0);
        }

        assertEquals("Bearer clave-de-prueba", autorizacion.get());
        assertTrue(cuerpo.get().contains("ana@example.org"));
        assertTrue(cuerpo.get().contains("no-reply@example.org"));
        assertTrue(cuerpo.get().contains("secreto-1"));
    }

    @Test
    void resendConRespuestaDeErrorFallaSinExponerDatos() throws IOException {
        HttpServer servidor = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        servidor.createContext("/emails", exchange -> {
            exchange.sendResponseHeaders(422, -1);
            exchange.close();
        });
        servidor.start();
        CorreoException error;
        try {
            ResendCorreoSender sender = new ResendCorreoSender(
                    "http://127.0.0.1:" + servidor.getAddress().getPort(),
                    "clave-de-prueba",
                    "no-reply@example.org"
            );
            error = assertThrows(CorreoException.class, () -> sender.enviar(MENSAJE));
        } finally {
            servidor.stop(0);
        }

        assertEquals("Resend respondio HTTP 422", error.getMessage());
        assertFalse(error.getMessage().contains("clave-de-prueba"));
    }

    @Test
    void mensajeNoImprimeSuTexto() {
        assertFalse(MENSAJE.toString().contains("secreto-1"));
    }
}
