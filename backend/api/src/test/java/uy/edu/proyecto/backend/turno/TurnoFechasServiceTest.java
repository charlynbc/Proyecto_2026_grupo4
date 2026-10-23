package uy.edu.proyecto.backend.turno;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.ConsultaParaCancelar;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.NumeroExistente;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.RecursoTurno;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.TurnoFecha;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TurnoFechasServiceTest {

    private static final LocalDate HOY = LocalDate.of(2026, 10, 21);
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-10-21T12:00:00Z"),
            ZoneId.of("America/Montevideo")
    );

    @Mock
    private TurnoFechasRepository repository;

    @Mock
    private ApplicationEventPublisher eventPublisher;

    private TurnoFechasService service;

    @BeforeEach
    void setUp() {
        service = new TurnoFechasService(repository, RELOJ, eventPublisher);
    }

    @Test
    void previsualizaVariosTurnosYTotalAgendado() {
        when(repository.buscarTurnos(List.of(301L, 308L))).thenReturn(List.of(
                turno(301L, "ACTIVO", HOY, 2),
                turno(308L, "ACTIVO", HOY.plusDays(7), 3)
        ));

        VistaPreviaSuspensionDTO response = service.previsualizar(
                new PrevisualizarSuspensionRequest(List.of(308L, 301L))
        );

        assertEquals(5, response.cantidadConsultasACancelar());
        assertEquals(List.of(301L, 308L), response.fechasAfectadas().stream()
                .map(VistaPreviaSuspensionDTO.FechaAfectada::turnoId)
                .toList());
        verify(repository, never()).actualizarEstadoTurno(
                eq(301L),
                eq("SUSPENDIDO")
        );
    }

    @Test
    void previsualizacionRechazaIdsDuplicadosSinConsultarBase() {
        ApiException exception = assertThrows(ApiException.class, () ->
                service.previsualizar(
                        new PrevisualizarSuspensionRequest(List.of(301L, 301L))
                )
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaFormatoDeFechaInvalidoAntesDeBloquearRegistros() {
        FiltroFechasRequest filtroInvalido =
                new FiltroFechasRequest(17L, 3L, "21/10/2026", "2026-10-28");

        ApiException exception = assertThrows(ApiException.class, () ->
                service.suspender(
                        new SuspenderFechasRequest(
                                filtroInvalido, List.of(301L), null, 0
                        ),
                        41L
                )
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void previsualizacionRechazaTurnoInexistente() {
        when(repository.buscarTurnos(List.of(301L, 308L)))
                .thenReturn(List.of(turno(301L, "ACTIVO", HOY, 0)));

        ApiException exception = assertThrows(ApiException.class, () ->
                service.previsualizar(
                        new PrevisualizarSuspensionRequest(List.of(301L, 308L))
                )
        );

        assertEquals("NO_ENCONTRADO", exception.getCode());
    }

    @Test
    void previsualizacionRechazaTurnoSuspendidoYFechaPasada() {
        when(repository.buscarTurnos(List.of(301L)))
                .thenReturn(List.of(turno(301L, "SUSPENDIDO", HOY, 0)));
        ApiException estado = assertThrows(ApiException.class, () ->
                service.previsualizar(new PrevisualizarSuspensionRequest(List.of(301L)))
        );
        assertEquals("TURNO_NO_SUSPENDIBLE", estado.getCode());

        when(repository.buscarTurnos(List.of(302L)))
                .thenReturn(List.of(turno(302L, "ACTIVO", HOY.minusDays(1), 0)));
        ApiException fecha = assertThrows(ApiException.class, () ->
                service.previsualizar(new PrevisualizarSuspensionRequest(List.of(302L)))
        );
        assertEquals("TURNO_NO_SUSPENDIBLE", fecha.getCode());
    }

    @Test
    void suspendeTurnosCancelaConsultasYPublicaEntregaTrasCommit() {
        List<Long> ids = List.of(301L, 308L);
        FiltroFechasRequest filtro = filtro();
        List<TurnoFecha> turnos = List.of(
                turno(301L, "ACTIVO", HOY, 1),
                turno(308L, "ACTIVO", HOY.plusDays(7), 1)
        );
        when(repository.bloquearTurnos(ids)).thenReturn(ids);
        when(repository.buscarTurnos(ids)).thenReturn(turnos);
        when(repository.bloquearConsultasAgendadas(ids)).thenReturn(List.of(
                consulta(900L, 301L),
                consulta(901L, 308L)
        ));
        when(repository.crearEvento(eq(301L), eq(41L), eq("SUSPENSION"), eq("Aviso")))
                .thenReturn(7001L);
        when(repository.crearEvento(eq(308L), eq(41L), eq("SUSPENSION"), eq("Aviso")))
                .thenReturn(7002L);
        when(repository.cancelarConsulta(
                eq(900L), eq(41L), org.mockito.ArgumentMatchers.any(),
                eq("Aviso"), eq(7001L)
        )).thenReturn(1);
        when(repository.cancelarConsulta(
                eq(901L), eq(41L), org.mockito.ArgumentMatchers.any(),
                eq("Aviso"), eq(7002L)
        )).thenReturn(1);
        when(repository.crearNotificacionSuspension(eq(900L), org.mockito.ArgumentMatchers.anyString()))
                .thenReturn(8001L);
        when(repository.crearNotificacionSuspension(eq(901L), org.mockito.ArgumentMatchers.anyString()))
                .thenReturn(8002L);
        when(repository.registrarEnviosNotificacion(8001L, 501L, "socio@example.com"))
                .thenReturn(List.of(6001L));
        when(repository.registrarEnviosNotificacion(8002L, 502L, "socia@example.com"))
                .thenReturn(List.of(6002L));

        ResultadoFechasDTO response = service.suspender(
                new SuspenderFechasRequest(filtro, ids, " Aviso ", 2),
                41L
        );

        assertEquals(2, response.turnos().size());
        assertEquals(2, response.consultasCanceladas());
        verify(repository).actualizarEstadoTurno(301L, "SUSPENDIDO");
        verify(repository).actualizarEstadoTurno(308L, "SUSPENDIDO");
        verify(eventPublisher).publishEvent(
                new TurnoFechasService.EnviosSuspensionSolicitados(
                        List.of(6001L, 6002L)
                )
        );
    }

    @Test
    void suspensionRechazaConfirmacionDesactualizadaSinAplicarCambios() {
        List<Long> ids = List.of(301L);
        when(repository.bloquearTurnos(ids)).thenReturn(ids);
        when(repository.buscarTurnos(ids)).thenReturn(List.of(
                turno(301L, "ACTIVO", HOY, 1)
        ));
        when(repository.bloquearConsultasAgendadas(ids))
                .thenReturn(List.of(consulta(900L, 301L)));

        ApiException exception = assertThrows(ApiException.class, () ->
                service.suspender(
                        new SuspenderFechasRequest(filtro(), ids, null, 0),
                        41L
                )
        );

        assertEquals("CONFIRMACION_DESACTUALIZADA", exception.getCode());
        verify(repository, never()).crearEvento(
                eq(301L), eq(41L), eq("SUSPENSION"), org.mockito.ArgumentMatchers.any()
        );
        verify(repository, never()).actualizarEstadoTurno(
                eq(301L), eq("SUSPENDIDO")
        );
    }

    @Test
    void falloDuranteCancelacionNoPublicaEnviosYOperacionEsTransaccional()
            throws NoSuchMethodException {
        List<Long> ids = List.of(301L);
        when(repository.bloquearTurnos(ids)).thenReturn(ids);
        when(repository.buscarTurnos(ids)).thenReturn(List.of(
                turno(301L, "ACTIVO", HOY, 1)
        ));
        when(repository.bloquearConsultasAgendadas(ids)).thenReturn(List.of(
                consulta(900L, 301L)
        ));
        when(repository.crearEvento(301L, 41L, "SUSPENSION", null))
                .thenReturn(7001L);
        when(repository.cancelarConsulta(
                eq(900L), eq(41L), org.mockito.ArgumentMatchers.any(),
                eq(null), eq(7001L)
        )).thenReturn(0);

        assertTrue(TurnoFechasService.class.getMethod(
                "suspender", SuspenderFechasRequest.class, Long.class
        ).isAnnotationPresent(Transactional.class));
        assertThrows(IllegalStateException.class, () ->
                service.suspender(
                        new SuspenderFechasRequest(filtro(), ids, null, 1),
                        41L
                )
        );

        verify(repository).actualizarEstadoTurno(301L, "SUSPENDIDO");
        verify(repository, never()).crearNotificacionSuspension(
                eq(900L), org.mockito.ArgumentMatchers.anyString()
        );
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void rehabilitaTurnoSinRecuperarConsultasCanceladas() {
        List<Long> ids = List.of(301L);
        TurnoFecha turno = turno(301L, "SUSPENDIDO", HOY, 0);
        RecursoTurno recurso = new RecursoTurno(
                301L, 21L, HOY, "SUSPENDIDO", 17L, true, 3L, 5L,
                400L, 1, LocalTime.of(9, 0), LocalTime.of(9, 20)
        );
        when(repository.buscarTurnos(ids)).thenReturn(List.of(turno));
        when(repository.buscarRecursos(ids)).thenReturn(List.of(recurso));
        when(repository.bloquearTurnos(ids)).thenReturn(ids);
        when(repository.crearEvento(301L, 41L, "REHABILITACION", null))
                .thenReturn(7001L);
        when(repository.buscarNumerosActivosEnFechas(
                ids, List.of(17L), List.of(5L), HOY, HOY
        )).thenReturn(List.of());

        ResultadoFechasDTO response = service.rehabilitar(
                new RehabilitarFechasRequest(filtro(), ids),
                41L
        );

        assertEquals(0, response.consultasCanceladas());
        verify(repository).actualizarEstadoTurno(301L, "ACTIVO");
        verify(repository, never()).bloquearConsultasAgendadas(anyList());
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void rehabilitacionRechazaMedicoInactivoYSolapamiento() {
        List<Long> ids = List.of(301L);
        TurnoFecha turno = turno(301L, "SUSPENDIDO", HOY, 0);
        RecursoTurno recurso = new RecursoTurno(
                301L, 21L, HOY, "SUSPENDIDO", 17L, false, 3L, 5L,
                400L, 1, LocalTime.of(9, 0), LocalTime.of(9, 20)
        );
        when(repository.buscarTurnos(ids)).thenReturn(List.of(turno));
        when(repository.buscarRecursos(ids)).thenReturn(List.of(recurso));
        when(repository.bloquearTurnos(ids)).thenReturn(ids);

        ApiException medico = assertThrows(ApiException.class, () ->
                service.rehabilitar(
                        new RehabilitarFechasRequest(filtro(), ids),
                        41L
                )
        );
        assertEquals("MEDICO_INACTIVO", medico.getCode());
        verify(repository, never()).actualizarEstadoTurno(
                eq(301L), eq("ACTIVO")
        );

        RecursoTurno medicoActivo = new RecursoTurno(
                301L, 21L, HOY, "SUSPENDIDO", 17L, true, 3L, 5L,
                400L, 1, LocalTime.of(9, 0), LocalTime.of(9, 20)
        );
        when(repository.buscarRecursos(ids)).thenReturn(List.of(medicoActivo));
        when(repository.bloquearTurnos(ids)).thenReturn(ids);
        when(repository.buscarNumerosActivosEnFechas(
                ids, List.of(17L), List.of(5L), HOY, HOY
        )).thenReturn(List.of(new NumeroExistente(
                999L, HOY, 17L, 9L, 2,
                LocalTime.of(9, 15), LocalTime.of(9, 35)
        )));

        ApiException solapamiento = assertThrows(ApiException.class, () ->
                service.rehabilitar(
                        new RehabilitarFechasRequest(filtro(), ids),
                        41L
                )
        );
        assertEquals("SOLAPAMIENTO_TURNO", solapamiento.getCode());
        verify(repository, never()).actualizarEstadoTurno(
                eq(301L), eq("ACTIVO")
        );
    }

    private TurnoFecha turno(
            Long id,
            String estado,
            LocalDate fecha,
            int consultas
    ) {
        return new TurnoFecha(
                id, id + 1000, fecha, estado, 17L, 3L, 5L,
                "09:00", "09:20", consultas
        );
    }

    private ConsultaParaCancelar consulta(Long id, Long turnoId) {
        return new ConsultaParaCancelar(
                id, id - 399, id + 100, turnoId, HOY,
                LocalTime.of(9, 0), LocalTime.of(9, 20), 1,
                id == 900L ? "socio@example.com" : "socia@example.com"
        );
    }

    private FiltroFechasRequest filtro() {
        return new FiltroFechasRequest(17L, 3L, "2026-10-21", "2026-10-28");
    }
}
