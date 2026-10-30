package uy.edu.proyecto.backend.agenda;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.agenda.CancelacionFuncionarioRepository.DatosConsulta;

class CancelacionFuncionarioServiceTest {
    private CancelacionFuncionarioRepository repository;
    private ConsultaRepository consultaRepository;
    private TurnoFechasRepository notificaciones;
    private ApplicationEventPublisher events;
    private CancelacionFuncionarioService service;

    @BeforeEach
    void setUp() {
        repository = mock(CancelacionFuncionarioRepository.class);
        consultaRepository = mock(ConsultaRepository.class);
        notificaciones = mock(TurnoFechasRepository.class);
        events = mock(ApplicationEventPublisher.class);
        service = new CancelacionFuncionarioService(repository, consultaRepository,
                notificaciones, events,
                Clock.fixed(Instant.parse("2026-10-30T12:00:00Z"),
                        ZoneId.of("America/Montevideo")));
        when(repository.ciFuncionario(5L)).thenReturn(Optional.of("87654321"));
        when(repository.buscarSocio(12L)).thenReturn(Optional.of(7L));
        when(consultaRepository.bloquearSocioHabilitado(7L)).thenReturn(true);
    }

    private DatosConsulta datos(String ci, LocalDate fecha, LocalTime hora) {
        return new DatosConsulta(7L, ci, "socio@example.com", "AGENDADA",
                fecha, hora, LocalDate.of(2026, 12, 15));
    }

    @Test
    void registraFuncionarioYDevuelvePaseVigente() {
        when(repository.bloquearConsulta(12L, 7L)).thenReturn(
                Optional.of(datos("12345678", LocalDate.of(2026, 11, 1), LocalTime.NOON)));
        when(repository.cancelar(12L, 5L)).thenReturn(
                Optional.of(OffsetDateTime.parse("2026-10-30T09:01:00-03:00")));
        when(repository.crearNotificacion(12L, LocalDate.of(2026, 11, 1)))
                .thenReturn(90L);
        when(notificaciones.registrarEnviosNotificacion(90L, 7L, "socio@example.com"))
                .thenReturn(List.of(91L));

        CancelacionDTO respuesta = service.cancelar(5L, "12");

        assertEquals("CANCELADA_SOCIO", respuesta.estado());
        assertEquals(true, respuesta.paseDevuelto());
        verify(repository).cancelar(12L, 5L);
        verify(events).publishEvent(any());
    }

    @Test
    void rechazaConflictoDeInteresSinCancelar() {
        when(repository.bloquearConsulta(12L, 7L)).thenReturn(
                Optional.of(datos("87654321", LocalDate.of(2026, 11, 1), LocalTime.NOON)));
        ApiException error = assertThrows(ApiException.class, () -> service.cancelar(5L, "12"));
        assertEquals("CONFLICTO_INTERES", error.getCode());
        verify(repository, never()).cancelar(any(), any());
    }

    @Test
    void rechazaCancelacionFueraDePlazo() {
        when(repository.bloquearConsulta(12L, 7L)).thenReturn(
                Optional.of(datos("12345678", LocalDate.of(2026, 10, 30), LocalTime.of(10, 0))));
        ApiException error = assertThrows(ApiException.class, () -> service.cancelar(5L, "12"));
        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        verify(repository, never()).cancelar(any(), any());
    }
}
