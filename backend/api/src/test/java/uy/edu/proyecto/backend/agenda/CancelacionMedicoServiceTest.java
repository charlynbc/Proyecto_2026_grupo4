package uy.edu.proyecto.backend.agenda;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

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

import uy.edu.proyecto.backend.agenda.CancelacionMedicoRepository.DatosConsulta;
import uy.edu.proyecto.backend.agenda.CancelacionMedicoRepository.ResumenCancelable;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.ConsultaParaCancelar;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.TurnoFecha;
import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosSuspensionSolicitados;

class CancelacionMedicoServiceTest {

    // 2026-10-30T12:00:00Z = 09:00 en Montevideo; el límite de 2 h son las 11:00 locales.
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-10-30T12:00:00Z"), ZoneId.of("America/Montevideo"));
    private static final LocalDate HOY = LocalDate.of(2026, 10, 30);

    private CancelacionMedicoRepository repository;
    private ConsultaRepository consultaRepository;
    private TurnoFechasRepository turnoFechas;
    private ApplicationEventPublisher events;
    private CancelacionMedicoService service;

    @BeforeEach
    void setUp() {
        repository = mock(CancelacionMedicoRepository.class);
        consultaRepository = mock(ConsultaRepository.class);
        turnoFechas = mock(TurnoFechasRepository.class);
        events = mock(ApplicationEventPublisher.class);
        service = new CancelacionMedicoService(
                repository, consultaRepository, turnoFechas, events, RELOJ);
        when(repository.ciMedico(5L)).thenReturn(Optional.of("10000044"));
    }

    private DatosConsulta datos(String ciSocio, LocalDate fecha, LocalTime hora) {
        return new DatosConsulta(7L, ciSocio, "socio@example.com", "AGENDADA",
                fecha, hora, LocalDate.of(2026, 12, 15));
    }

    private void consultaAgendadaDelMedico(DatosConsulta datos) {
        when(repository.buscarSocioEnConsultaDelMedico(12L, 5L)).thenReturn(Optional.of(7L));
        when(consultaRepository.bloquearSocioHabilitado(7L)).thenReturn(true);
        when(repository.bloquearConsultaDelMedico(12L, 7L, 5L))
                .thenReturn(Optional.of(datos));
    }

    /* ---------- Cancelación individual ---------- */

    @Test
    void cancelacionIndividualCorrectaDevuelvePaseVigenteYNotifica() {
        consultaAgendadaDelMedico(datos("20000012", HOY, LocalTime.NOON));
        when(repository.cancelarConsulta(12L, 5L, "Imprevisto"))
                .thenReturn(Optional.of(OffsetDateTime.parse("2026-10-30T09:01:00-03:00")));
        when(repository.crearNotificacionCancelacion(eq(12L), anyString())).thenReturn(90L);
        when(turnoFechas.registrarEnviosNotificacion(90L, 7L, "socio@example.com"))
                .thenReturn(List.of(91L));

        CancelacionDTO respuesta = service.cancelarConsulta(5L, "12", "Imprevisto");

        assertEquals("CANCELADA_INSTITUCION", respuesta.estado());
        assertTrue(respuesta.paseDevuelto());
        verify(repository).cancelarConsulta(12L, 5L, "Imprevisto");
        verify(repository).crearNotificacionCancelacion(eq(12L),
                org.mockito.ArgumentMatchers.contains("Imprevisto"));
        verify(events).publishEvent(any(EnviosSuspensionSolicitados.class));
    }

    @Test
    void motivoVacioONuloDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "12", "   "));
        assertEquals("VALIDACION", error.getCode());
        error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "12", null));
        assertEquals("VALIDACION", error.getCode());
        verify(repository, never()).cancelarConsulta(anyLong(), anyLong(), anyString());
    }

    @Test
    void identificadorNoNumericoDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "abc", "Motivo"));
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void consultaDeOtroMedicoDevuelve404() {
        when(repository.buscarSocioEnConsultaDelMedico(12L, 5L)).thenReturn(Optional.empty());
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "12", "Motivo"));
        assertEquals("NO_ENCONTRADO", error.getCode());
        assertEquals(404, error.getStatus().value());
    }

    @Test
    void consultaYaCanceladaDevuelve409() {
        DatosConsulta datos = datos("20000012", HOY, LocalTime.NOON);
        consultaAgendadaDelMedico(new DatosConsulta(7L, "20000012", "socio@example.com",
                "CANCELADA_SOCIO", datos.fecha(), datos.horaInicio(), datos.venceElPase()));
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "12", "Motivo"));
        assertEquals("CONSULTA_NO_AGENDADA", error.getCode());
        verify(repository, never()).cancelarConsulta(anyLong(), anyLong(), anyString());
    }

    @Test
    void menosDeDosHorasDevuelve409() {
        consultaAgendadaDelMedico(datos("20000012", HOY, LocalTime.of(10, 30)));
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "12", "Motivo"));
        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        verify(repository, never()).cancelarConsulta(anyLong(), anyLong(), anyString());
    }

    @Test
    void limiteExactoDeDosHorasPermiteCancelar() {
        consultaAgendadaDelMedico(datos("20000012", HOY, LocalTime.of(11, 0)));
        when(repository.cancelarConsulta(eq(12L), eq(5L), anyString()))
                .thenReturn(Optional.of(OffsetDateTime.parse("2026-10-30T09:00:00-03:00")));
        when(repository.crearNotificacionCancelacion(eq(12L), anyString())).thenReturn(90L);
        when(turnoFechas.registrarEnviosNotificacion(anyLong(), anyLong(), anyString()))
                .thenReturn(List.of());

        CancelacionDTO respuesta = service.cancelarConsulta(5L, "12", "Motivo");
        assertEquals("CANCELADA_INSTITUCION", respuesta.estado());
    }

    @Test
    void conflictoDeInteresDevuelve403SinCancelar() {
        consultaAgendadaDelMedico(datos("10000044", HOY, LocalTime.NOON));
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "12", "Motivo"));
        assertEquals("CONFLICTO_DE_INTERES", error.getCode());
        assertEquals(403, error.getStatus().value());
        verify(repository, never()).cancelarConsulta(anyLong(), anyLong(), anyString());
    }

    @Test
    void medicoNoHabilitadoDevuelve403() {
        when(repository.ciMedico(5L)).thenReturn(Optional.empty());
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarConsulta(5L, "12", "Motivo"));
        assertEquals("ACCESO_DENEGADO", error.getCode());
    }

    @Test
    void paseVencidoNoSeDevuelve() {
        DatosConsulta datos = new DatosConsulta(7L, "20000012", "socio@example.com",
                "AGENDADA", HOY, LocalTime.NOON, HOY.minusDays(1));
        consultaAgendadaDelMedico(datos);
        when(repository.cancelarConsulta(eq(12L), eq(5L), anyString()))
                .thenReturn(Optional.of(OffsetDateTime.parse("2026-10-30T09:00:00-03:00")));
        when(repository.crearNotificacionCancelacion(eq(12L), anyString())).thenReturn(90L);
        when(turnoFechas.registrarEnviosNotificacion(anyLong(), anyLong(), anyString()))
                .thenReturn(List.of());

        CancelacionDTO respuesta = service.cancelarConsulta(5L, "12", "Motivo");
        assertFalse(respuesta.paseDevuelto());
    }

    /* ---------- Cancelación masiva (turno de una fecha) ---------- */

    private TurnoFecha turnoActivo(String estado, LocalDate fecha) {
        return new TurnoFecha(30L, 3L, fecha, estado, 5L, 9L, 4L,
                "10:00", "11:00", 2);
    }

    private ConsultaParaCancelar consultaDeTurno(long id, long socioId, LocalDate fecha,
            LocalTime inicio) {
        return new ConsultaParaCancelar(id, socioId, 100L + id, 30L, fecha,
                inicio, inicio.plusMinutes(20), (int) id, "socio" + id + "@example.com");
    }

    private void turnoDelMedicoConConsultas(TurnoFecha turno,
            List<ConsultaParaCancelar> consultas) {
        when(turnoFechas.bloquearTurnos(List.of(30L))).thenReturn(List.of(30L));
        when(turnoFechas.buscarTurnos(List.of(30L))).thenReturn(List.of(turno));
        when(turnoFechas.bloquearConsultasAgendadas(List.of(30L))).thenReturn(consultas);
    }

    @Test
    void cancelacionMasivaCorrectaSuspendeFechaYNotifica() {
        List<ConsultaParaCancelar> consultas = List.of(
                consultaDeTurno(1L, 7L, HOY, LocalTime.of(12, 0)),
                consultaDeTurno(2L, 8L, HOY, LocalTime.of(12, 20)));
        turnoDelMedicoConConsultas(turnoActivo("ACTIVO", HOY), consultas);
        when(repository.resumenCancelables(List.of(1L, 2L))).thenReturn(List.of(
                new ResumenCancelable(1L, "20000012", HOY.plusDays(10)),
                new ResumenCancelable(2L, "20000021", HOY.minusDays(1))));
        when(turnoFechas.crearEvento(30L, 5L, "SUSPENSION", "Imprevisto")).thenReturn(60L);
        when(turnoFechas.cancelarConsulta(anyLong(), eq(5L), any(), eq("Imprevisto"),
                eq(60L))).thenReturn(1);
        when(turnoFechas.crearNotificacionSuspension(anyLong(), anyString()))
                .thenReturn(90L, 91L);
        when(turnoFechas.registrarEnviosNotificacion(anyLong(), anyLong(), anyString()))
                .thenReturn(List.of(95L));

        CancelacionTurnoMedicoDTO respuesta = service.cancelarTurno(5L, "30", "Imprevisto");

        assertEquals("SUSPENDIDO", respuesta.estado());
        assertEquals(2, respuesta.consultasCanceladas());
        assertEquals(1, respuesta.pasesDevueltos());
        verify(turnoFechas).actualizarEstadoTurno(30L, "SUSPENDIDO");
        verify(turnoFechas).crearNotificacionSuspension(eq(1L),
                org.mockito.ArgumentMatchers.contains("Imprevisto"));
        verify(events).publishEvent(any(EnviosSuspensionSolicitados.class));
    }

    @Test
    void cancelacionMasivaSinConsultasSuspendeLaFecha() {
        turnoDelMedicoConConsultas(turnoActivo("ACTIVO", HOY.plusDays(1)), List.of());
        when(turnoFechas.crearEvento(30L, 5L, "SUSPENSION", "Imprevisto")).thenReturn(60L);

        CancelacionTurnoMedicoDTO respuesta = service.cancelarTurno(5L, "30", "Imprevisto");

        assertEquals(0, respuesta.consultasCanceladas());
        assertEquals(0, respuesta.pasesDevueltos());
        verify(turnoFechas).actualizarEstadoTurno(30L, "SUSPENDIDO");
    }

    @Test
    void turnoDeOtroMedicoDevuelve404() {
        TurnoFecha ajeno = new TurnoFecha(30L, 3L, HOY, "ACTIVO", 99L, 9L, 4L,
                "10:00", "11:00", 0);
        turnoDelMedicoConConsultas(ajeno, List.of());
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarTurno(5L, "30", "Motivo"));
        assertEquals("NO_ENCONTRADO", error.getCode());
        verify(turnoFechas, never()).actualizarEstadoTurno(anyLong(), anyString());
    }

    @Test
    void turnoInexistenteDevuelve404() {
        when(turnoFechas.bloquearTurnos(List.of(30L))).thenReturn(List.of());
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarTurno(5L, "30", "Motivo"));
        assertEquals("NO_ENCONTRADO", error.getCode());
    }

    @Test
    void turnoYaSuspendidoDevuelve409() {
        turnoDelMedicoConConsultas(turnoActivo("SUSPENDIDO", HOY), List.of());
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarTurno(5L, "30", "Motivo"));
        assertEquals("TURNO_NO_SUSPENDIBLE", error.getCode());
    }

    @Test
    void turnoDeFechaPasadaDevuelve409() {
        turnoDelMedicoConConsultas(turnoActivo("ACTIVO", HOY.minusDays(1)), List.of());
        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarTurno(5L, "30", "Motivo"));
        assertEquals("TURNO_NO_SUSPENDIBLE", error.getCode());
    }

    @Test
    void unaConsultaFueraDePlazoRechazaTodaLaOperacion() {
        List<ConsultaParaCancelar> consultas = List.of(
                consultaDeTurno(1L, 7L, HOY, LocalTime.of(12, 0)),
                consultaDeTurno(2L, 8L, HOY, LocalTime.of(10, 30)));
        turnoDelMedicoConConsultas(turnoActivo("ACTIVO", HOY), consultas);
        when(repository.resumenCancelables(List.of(1L, 2L))).thenReturn(List.of(
                new ResumenCancelable(1L, "20000012", null),
                new ResumenCancelable(2L, "20000021", null)));

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarTurno(5L, "30", "Motivo"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        verify(turnoFechas, never()).actualizarEstadoTurno(anyLong(), anyString());
        verify(turnoFechas, never()).cancelarConsulta(anyLong(), anyLong(), any(),
                anyString(), anyLong());
    }

    @Test
    void conflictoDeInteresEnMasivaRechazaTodaLaOperacion() {
        List<ConsultaParaCancelar> consultas = List.of(
                consultaDeTurno(1L, 7L, HOY, LocalTime.of(12, 0)),
                consultaDeTurno(2L, 5L, HOY, LocalTime.of(12, 20)));
        turnoDelMedicoConConsultas(turnoActivo("ACTIVO", HOY), consultas);
        when(repository.resumenCancelables(List.of(1L, 2L))).thenReturn(List.of(
                new ResumenCancelable(1L, "20000012", null),
                new ResumenCancelable(2L, "10000044", null)));

        ApiException error = assertThrows(ApiException.class,
                () -> service.cancelarTurno(5L, "30", "Motivo"));

        assertEquals("CONFLICTO_DE_INTERES", error.getCode());
        verify(turnoFechas, never()).actualizarEstadoTurno(anyLong(), anyString());
    }

    @Test
    void falloAlCancelarPropagaExcepcionYRevienteLaTransaccion() {
        List<ConsultaParaCancelar> consultas = List.of(
                consultaDeTurno(1L, 7L, HOY, LocalTime.of(12, 0)));
        turnoDelMedicoConConsultas(turnoActivo("ACTIVO", HOY), consultas);
        when(repository.resumenCancelables(List.of(1L)))
                .thenReturn(List.of(new ResumenCancelable(1L, "20000012", null)));
        when(turnoFechas.crearEvento(30L, 5L, "SUSPENSION", "Motivo")).thenReturn(60L);
        when(turnoFechas.cancelarConsulta(anyLong(), anyLong(), any(), anyString(), anyLong()))
                .thenReturn(0);

        assertThrows(IllegalStateException.class,
                () -> service.cancelarTurno(5L, "30", "Motivo"));
    }
}
