package uy.edu.proyecto.backend.notificacion;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EnvioNotificacionPollerTest {

    @Mock
    private EnvioNotificacionDispatcher dispatcher;

    @Test
    void despachaPendientesHastaQueNoQuedenMas() {
        when(dispatcher.despacharSiguientePendiente()).thenReturn(true, true, false);

        new EnvioNotificacionPoller(dispatcher).despacharPendientes();

        verify(dispatcher, times(3)).despacharSiguientePendiente();
    }

    @Test
    void noDespachaMasDe100PorCiclo() {
        when(dispatcher.despacharSiguientePendiente()).thenReturn(true);

        new EnvioNotificacionPoller(dispatcher).despacharPendientes();

        verify(dispatcher, times(100)).despacharSiguientePendiente();
    }

    @Test
    void unaFallaCortaElCicloSinSalirComoExcepcionYSeReintentaEnElSiguiente() {
        when(dispatcher.despacharSiguientePendiente())
                .thenThrow(new IllegalStateException("base caida"))
                .thenReturn(false);
        EnvioNotificacionPoller poller = new EnvioNotificacionPoller(dispatcher);

        assertDoesNotThrow(poller::despacharPendientes);
        verify(dispatcher, times(1)).despacharSiguientePendiente();

        assertDoesNotThrow(poller::despacharPendientes);
        verify(dispatcher, times(2)).despacharSiguientePendiente();
    }
}
