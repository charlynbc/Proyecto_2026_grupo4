package uy.edu.proyecto.backend.notificacion;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosNotificacionSolicitados;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class EnvioNotificacionListenerTest {

    @Mock
    private EnvioNotificacionDispatcher dispatcher;

    @Test
    void despachaTodosLosEnviosDelEventoEnOrden() {
        new EnvioNotificacionListener(dispatcher)
                .enviar(new EnviosNotificacionSolicitados(List.of(601L, 602L, 603L)));

        InOrder orden = Mockito.inOrder(dispatcher);
        orden.verify(dispatcher).despachar(601L);
        orden.verify(dispatcher).despachar(602L);
        orden.verify(dispatcher).despachar(603L);
    }

    @Test
    void unEnvioQueFallaNoImpideDespacharLosSiguientesNiSaleComoExcepcion() {
        doThrow(new IllegalStateException("base caida")).when(dispatcher).despachar(601L);

        assertDoesNotThrow(() -> new EnvioNotificacionListener(dispatcher)
                .enviar(new EnviosNotificacionSolicitados(List.of(601L, 602L))));

        verify(dispatcher).despachar(602L);
    }
}
