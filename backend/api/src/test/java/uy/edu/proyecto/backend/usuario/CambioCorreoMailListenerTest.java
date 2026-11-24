package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;

class CambioCorreoMailListenerTest {

    private final CorreoSender sender = mock(CorreoSender.class);
    private final CambioCorreoMailListener listener =
            new CambioCorreoMailListener(sender, "https://app.example.org/cambio-correo");

    @Test
    void elEnlaceDelCorreoVaSinNumeralYConElToken() {
        listener.enviarEnlace(new CambioCorreoSolicitado(
                31L, "nuevo@example.org", "Ana", "token-cambio", 24));

        ArgumentCaptor<CorreoMensaje> mensaje = ArgumentCaptor.forClass(CorreoMensaje.class);
        verify(sender).enviar(mensaje.capture());
        assertEquals("nuevo@example.org", mensaje.getValue().para());
        assertTrue(mensaje.getValue().texto().contains(
                "https://app.example.org/cambio-correo?token=token-cambio"));
        assertFalse(mensaje.getValue().texto().contains("#"));
        assertTrue(mensaje.getValue().texto().contains("vence en 24 horas"));
    }
}
