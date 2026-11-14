package uy.edu.proyecto.backend.notificacion;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosNotificacionSolicitados;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificacionEnviosTest {

    private static final Long NOTIFICACION_ID = 701L;
    private static final Long SOCIO_ID = 91L;

    @Mock
    private TurnoFechasRepository repository;

    @Mock
    private ApplicationEventPublisher events;

    private NotificacionEnvios envios() {
        return new NotificacionEnvios(repository, events);
    }

    @Test
    void conCorreoYDosDispositivosPideLaEntregaDeLasTresFilas() {
        when(repository.correoDelSocio(SOCIO_ID)).thenReturn(Optional.of("socio@example.com"));
        when(repository.registrarEnviosNotificacion(
                NOTIFICACION_ID, SOCIO_ID, "socio@example.com"))
                .thenReturn(List.of(801L, 802L, 803L));

        envios().solicitar(NOTIFICACION_ID, SOCIO_ID);

        verify(events).publishEvent(
                new EnviosNotificacionSolicitados(List.of(801L, 802L, 803L)));
    }

    @Test
    void sinCorreoSoloCreaLasFilasDePush() {
        when(repository.correoDelSocio(SOCIO_ID)).thenReturn(Optional.empty());
        when(repository.registrarEnviosNotificacion(NOTIFICACION_ID, SOCIO_ID, null))
                .thenReturn(List.of(811L, 812L));

        envios().solicitar(NOTIFICACION_ID, SOCIO_ID);

        verify(events).publishEvent(new EnviosNotificacionSolicitados(List.of(811L, 812L)));
    }

    @Test
    void sinCorreoNiDispositivosNoSePideNingunaEntrega() {
        when(repository.correoDelSocio(SOCIO_ID)).thenReturn(Optional.empty());
        when(repository.registrarEnviosNotificacion(NOTIFICACION_ID, SOCIO_ID, null))
                .thenReturn(List.of());

        envios().solicitar(NOTIFICACION_ID, SOCIO_ID);

        verifyNoInteractions(events);
    }
}
