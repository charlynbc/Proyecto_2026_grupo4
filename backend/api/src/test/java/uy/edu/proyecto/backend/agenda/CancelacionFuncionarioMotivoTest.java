package uy.edu.proyecto.backend.agenda;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
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

import uy.edu.proyecto.backend.agenda.CancelacionFuncionarioRepository.DatosConsulta;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;

/** RF-19: el funcionario cancela a pedido del socio o por otro motivo, con motivo. */
class CancelacionFuncionarioMotivoTest {
    private static final LocalDate FECHA = LocalDate.of(2026, 11, 1);

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
                        ZoneId.of("America/Montevideo")),
                ParametroService.porDefecto());
        when(repository.ciFuncionario(5L)).thenReturn(Optional.of("87654321"));
        when(repository.buscarSocio(12L)).thenReturn(Optional.of(7L));
        when(consultaRepository.bloquearSocioHabilitado(7L)).thenReturn(true);
        when(repository.bloquearConsulta(12L, 7L)).thenReturn(Optional.of(
                new DatosConsulta(7L, "12345678", "socio@example.com", "AGENDADA",
                        FECHA, LocalTime.NOON, LocalDate.of(2026, 12, 15))));
        when(repository.cancelar(12L, 5L)).thenReturn(
                Optional.of(OffsetDateTime.parse("2026-10-30T09:01:00-03:00")));
        when(repository.crearNotificacion(12L, FECHA)).thenReturn(90L);
        when(notificaciones.registrarEnviosNotificacion(90L, 7L, "socio@example.com"))
                .thenReturn(List.of(91L));
    }

    private static String texto(int largo) {
        return "a".repeat(largo);
    }

    private ApiException rechazo(CancelacionFuncionarioRequest request) {
        return assertThrows(ApiException.class, () -> service.cancelar(5L, "12", request));
    }

    private void assertValidacion(ApiException error, String mensaje) {
        assertEquals(400, error.getStatus().value());
        assertEquals("VALIDACION", error.getCode());
        assertEquals(mensaje, error.getMessage());
    }

    /* ---------- Validación del motivo (solo con aPedidoDelSocio en false) ---------- */

    @Test
    void otroMotivoSinMotivoDaValidacion() {
        assertValidacion(rechazo(new CancelacionFuncionarioRequest(false, null)),
                "motivo es obligatorio");
    }

    @Test
    void otroMotivoConMotivoEnBlancoDaValidacion() {
        assertValidacion(rechazo(new CancelacionFuncionarioRequest(false, "   ")),
                "motivo es obligatorio");
    }

    @Test
    void otroMotivoConMotivoVacioDaValidacion() {
        assertValidacion(rechazo(new CancelacionFuncionarioRequest(false, "")),
                "motivo es obligatorio");
    }

    @Test
    void otroMotivoConMil1CaracteresDaValidacion() {
        assertValidacion(rechazo(new CancelacionFuncionarioRequest(false, texto(1001))),
                "motivo no puede superar 1000 caracteres");
    }

    @Test
    void elLargoSeMideDespuesDeRecortar() {
        // 1000 caracteres con espacios alrededor: recortado mide 1000 y pasa.
        preparaCancelacionInstitucional(texto(1000));

        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(false, "  " + texto(1000) + "  "));

        assertEquals("CANCELADA_INSTITUCION", respuesta.estado());
        verify(repository).cancelarPorInstitucion(12L, 5L, texto(1000));
    }

    @Test
    void otroMotivoConMilCaracteresPasa() {
        preparaCancelacionInstitucional(texto(1000));

        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(false, texto(1000)));

        assertEquals("CANCELADA_INSTITUCION", respuesta.estado());
    }

    @Test
    void elMotivoSeValidaAntesDeConsultarNada() {
        rechazo(new CancelacionFuncionarioRequest(false, null));

        verify(repository, never()).ciFuncionario(any());
        verify(repository, never()).buscarSocio(any());
        verify(repository, never()).cancelar(any(), any());
    }

    /* ---------- Por otro motivo: estado y motivo guardados ---------- */

    private void preparaCancelacionInstitucional(String motivoGuardado) {
        when(repository.cancelarPorInstitucion(12L, 5L, motivoGuardado)).thenReturn(
                Optional.of(OffsetDateTime.parse("2026-10-30T09:01:00-03:00")));
    }

    @Test
    void otroMotivoDejaCanceladaInstitucionConElMotivoRecortado() {
        preparaCancelacionInstitucional("Se rompio el equipo");

        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(false, "  Se rompio el equipo  "));

        assertEquals("CANCELADA_INSTITUCION", respuesta.estado());
        assertEquals(12L, respuesta.consultaId());
        assertEquals(OffsetDateTime.parse("2026-10-30T09:01:00-03:00"), respuesta.canceladaEn());
        verify(repository).cancelarPorInstitucion(12L, 5L, "Se rompio el equipo");
        verify(repository, never()).cancelar(any(), any());
    }

    @Test
    void otroMotivoDevuelveElPaseVigente() {
        preparaCancelacionInstitucional("Guardia");

        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(false, "Guardia"));

        assertEquals(true, respuesta.paseDevuelto());
    }

    @Test
    void aPedidoDelSocioConMotivoNoLoGuardaYQuedaCanceladaSocio() {
        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(true, "Esto no se guarda"));

        assertEquals("CANCELADA_SOCIO", respuesta.estado());
        verify(repository).cancelar(12L, 5L);
        verify(repository, never()).cancelarPorInstitucion(any(), any(), any());
    }

    @Test
    void otroMotivoSobreConsultaQueYaNoEstaAgendadaDa409() {
        when(repository.cancelarPorInstitucion(12L, 5L, "Guardia"))
                .thenReturn(Optional.empty());

        ApiException error = rechazo(new CancelacionFuncionarioRequest(false, "Guardia"));

        assertEquals(409, error.getStatus().value());
        assertEquals("CONSULTA_NO_AGENDADA", error.getCode());
    }

    @Test
    void otroMotivoRespetaElPlazoDeDosHoras() {
        when(repository.bloquearConsulta(12L, 7L)).thenReturn(Optional.of(
                new DatosConsulta(7L, "12345678", "socio@example.com", "AGENDADA",
                        LocalDate.of(2026, 10, 30), LocalTime.of(10, 0), null)));

        ApiException error = rechazo(new CancelacionFuncionarioRequest(false, "Guardia"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        verify(repository, never()).cancelarPorInstitucion(any(), any(), any());
    }

    @Test
    void otroMotivoRespetaElConflictoDeInteres() {
        when(repository.bloquearConsulta(12L, 7L)).thenReturn(Optional.of(
                new DatosConsulta(7L, "87654321", "socio@example.com", "AGENDADA",
                        FECHA, LocalTime.NOON, null)));

        ApiException error = rechazo(new CancelacionFuncionarioRequest(false, "Guardia"));

        assertEquals(403, error.getStatus().value());
        assertEquals("CONFLICTO_INTERES", error.getCode());
        verify(repository, never()).cancelarPorInstitucion(any(), any(), any());
    }

    /* ---------- Notificación al socio ---------- */

    @Test
    void elTextoPorOtroMotivoLlevaLaFechaConBarrasYElMotivo() {
        assertEquals("Tu consulta del 01/11/2026 fue cancelada por la institución."
                + " Motivo: Se rompio el equipo",
                CancelacionFuncionarioRepository.textoPorInstitucion(
                        LocalDate.of(2026, 11, 1), "Se rompio el equipo"));
    }

    @Test
    void elTextoNoMencionaAlFuncionario() {
        String texto = CancelacionFuncionarioRepository.textoPorInstitucion(
                LocalDate.of(2026, 12, 25), "Feriado");

        assertEquals("Tu consulta del 25/12/2026 fue cancelada por la institución."
                + " Motivo: Feriado", texto);
    }

    @Test
    void otroMotivoCreaLaNotificacionConElMotivoRecortado() {
        preparaCancelacionInstitucional("Guardia");
        when(repository.crearNotificacionPorInstitucion(12L, FECHA, "Guardia"))
                .thenReturn(92L);
        when(notificaciones.registrarEnviosNotificacion(92L, 7L, "socio@example.com"))
                .thenReturn(List.of(93L));

        service.cancelar(5L, "12", new CancelacionFuncionarioRequest(false, "  Guardia "));

        verify(repository).crearNotificacionPorInstitucion(12L, FECHA, "Guardia");
        verify(repository, never()).crearNotificacion(any(), any());
        verify(events).publishEvent(any(Object.class));
    }

    @Test
    void aPedidoDelSocioConservaLaNotificacionDeSiempre() {
        service.cancelar(5L, "12", new CancelacionFuncionarioRequest(true, "No va"));

        verify(repository).crearNotificacion(12L, FECHA);
        verify(repository, never()).crearNotificacionPorInstitucion(any(), any(), any());
    }

    /* ---------- A pedido del socio: el motivo no se valida ni se usa ---------- */

    @Test
    void sinCuerpoCancelaComoAntes() {
        CancelacionDTO respuesta = service.cancelar(5L, "12", null);

        assertEquals("CANCELADA_SOCIO", respuesta.estado());
        verify(repository).cancelar(12L, 5L);
    }

    @Test
    void aPedidoDelSocioAusenteSeTomaComoVerdadero() {
        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(null, null));

        assertEquals("CANCELADA_SOCIO", respuesta.estado());
    }

    @Test
    void aPedidoDelSocioIgnoraUnMotivoVacio() {
        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(true, "   "));

        assertEquals("CANCELADA_SOCIO", respuesta.estado());
    }

    @Test
    void aPedidoDelSocioIgnoraUnMotivoDeMil1Caracteres() {
        CancelacionDTO respuesta = service.cancelar(5L, "12",
                new CancelacionFuncionarioRequest(true, texto(1001)));

        assertEquals("CANCELADA_SOCIO", respuesta.estado());
    }
}
