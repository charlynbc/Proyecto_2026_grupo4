package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.slf4j.LoggerFactory;

import uy.edu.proyecto.backend.correo.CorreoException;
import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;

class PrimerIngresoMailListenerTest {

    private static final PrimerIngresoLinkSolicitado EVENTO =
            new PrimerIngresoLinkSolicitado(
                    12L,
                    "ana@example.org",
                    "Ana",
                    "token-unico"
            );

    private final CorreoSender sender = mock(CorreoSender.class);
    private final PrimerIngresoMailListener listener =
            new PrimerIngresoMailListener(
                    sender,
                    "https://app.example.org/#/primer-ingreso"
            );
    private final ListAppender<ILoggingEvent> logs = new ListAppender<>();
    private Logger logger;

    @BeforeEach
    void capturarLogs() {
        logger = (Logger) LoggerFactory.getLogger(PrimerIngresoMailListener.class);
        logs.start();
        logger.addAppender(logs);
    }

    @AfterEach
    void liberarLogs() {
        logger.detachAppender(logs);
    }

    @Test
    void enviaAlCorreoDeLaCuentaUnEnlaceDeUnSoloUsoConVencimiento() {
        listener.enviarEnlace(EVENTO);

        ArgumentCaptor<CorreoMensaje> mensaje =
                ArgumentCaptor.forClass(CorreoMensaje.class);
        verify(sender).enviar(mensaje.capture());
        assertTrue("ana@example.org".equals(mensaje.getValue().para()));
        assertTrue(mensaje.getValue().texto().contains(
                "https://app.example.org/#/primer-ingreso?token=token-unico"
        ));
        assertTrue(mensaje.getValue().texto().contains("vence en 24 horas"));
    }

    @Test
    void siFallaElProveedorNoPropagaNiRegistraTokenNiCorreo() {
        doThrow(new CorreoException("Resend respondio HTTP 500"))
                .when(sender).enviar(any());

        listener.enviarEnlace(EVENTO);

        assertFalse(logs.list.isEmpty());
        String salida = logs.list.stream()
                .map(ILoggingEvent::getFormattedMessage)
                .reduce("", String::concat);
        assertTrue(salida.contains("12"));
        assertFalse(salida.contains("token-unico"));
        assertFalse(salida.contains("ana@example.org"));
        assertTrue(logs.list.stream().allMatch(e -> e.getThrowableProxy() == null));
    }

    @Test
    void errorInesperadoDelProveedorTampocoPropagaNiExponeDatos() {
        doThrow(new IllegalStateException("fallo con token-unico"))
                .when(sender).enviar(any());

        listener.enviarEnlace(EVENTO);

        String salida = logs.list.stream()
                .map(ILoggingEvent::getFormattedMessage)
                .reduce("", String::concat);
        assertFalse(salida.contains("token-unico"));
    }

    @Test
    void elEventoNoImprimeElToken() {
        assertFalse(EVENTO.toString().contains("token-unico"));
        assertFalse(EVENTO.toString().contains("ana@example.org"));
    }
}
