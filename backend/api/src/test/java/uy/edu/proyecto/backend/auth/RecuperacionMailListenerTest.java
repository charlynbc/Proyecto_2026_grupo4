package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;

class RecuperacionMailListenerTest {

    private final CorreoSender sender = mock(CorreoSender.class);
    private final RecuperacionMailListener listener =
            new RecuperacionMailListener(sender, "https://app.example.org/recuperacion");

    @Test
    void elEnlaceDelCorreoVaSinNumeralYConElToken() {
        listener.enviarEnlace(new RecuperacionLinkSolicitado(
                21L, "ana@example.org", "Ana", "token-recuperacion", 24));

        ArgumentCaptor<CorreoMensaje> mensaje = ArgumentCaptor.forClass(CorreoMensaje.class);
        verify(sender).enviar(mensaje.capture());
        assertEquals("ana@example.org", mensaje.getValue().para());
        assertTrue(mensaje.getValue().texto().contains(
                "https://app.example.org/recuperacion?token=token-recuperacion"));
        assertFalse(mensaje.getValue().texto().contains("#"));
        assertTrue(mensaje.getValue().texto().contains("vence en 24 horas"));
    }
}
