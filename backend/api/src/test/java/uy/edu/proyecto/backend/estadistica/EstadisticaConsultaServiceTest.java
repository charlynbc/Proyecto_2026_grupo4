package uy.edu.proyecto.backend.estadistica;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class EstadisticaConsultaServiceTest {

    private static final ZoneId MONTEVIDEO = ZoneId.of("America/Montevideo");

    private final EstadisticaConsultaRepository repository = mock(EstadisticaConsultaRepository.class);

    private EstadisticaConsultaService servicioA(String instanteUtc) {
        return new EstadisticaConsultaService(
                repository, Clock.fixed(Instant.parse(instanteUtc), MONTEVIDEO));
    }

    @Test
    void sinParametrosUsaElMesEnCursoYLaFechaDeHoyEnMontevideo() {
        LocalDate desde = LocalDate.parse("2026-10-01");
        LocalDate hasta = LocalDate.parse("2026-10-31");
        when(repository.contarPorEstado(desde, hasta, LocalDate.parse("2026-10-15"))).thenReturn(Map.of());

        EstadisticaConsultaResponse r = servicioA("2026-10-15T12:00:00Z").calcular(null, null);

        assertEquals(desde, r.desde());
        assertEquals(hasta, r.hasta());
    }

    @Test
    void elDiaDeHoySeCalculaEnMontevideoYNoEnUtc() {
        // 2026-11-01T01:30Z sigue siendo 31 de octubre en Montevideo: ese dia aun no termino.
        when(repository.contarPorEstado(
                LocalDate.parse("2026-10-01"), LocalDate.parse("2026-10-31"), LocalDate.parse("2026-10-31")))
                .thenReturn(Map.of());

        servicioA("2026-11-01T01:30:00Z").calcular(null, null);

        verify(repository).contarPorEstado(
                LocalDate.parse("2026-10-01"), LocalDate.parse("2026-10-31"), LocalDate.parse("2026-10-31"));
    }

    @Test
    void periodoVacioDevuelveLosSieteEstadosEnCeroYSinDatos() {
        EstadisticaConsultaResponse r = EstadisticaConsultaService.armar(
                new PeriodoEstadistico(LocalDate.parse("2026-03-01"), LocalDate.parse("2026-03-31")), Map.of());

        assertEquals(List.of("AGENDADA", "ATENDIDA", "CANCELADA_SOCIO", "CANCELADA_INSTITUCION",
                "NO_ASISTIO", "NO_ATENDIDA", "NO_SE_PRESENTO"), List.copyOf(r.estados().keySet()));
        r.estados().values().forEach(cantidad -> assertEquals(0L, cantidad));
        assertEquals(0, r.totalConsultas());
        assertNull(r.porcentajeCancelacion());
        assertEquals("Sin datos", r.porcentajeCancelacionTexto());
    }

    private static EstadisticaConsultaResponse armar(Map<String, Long> contados) {
        return EstadisticaConsultaService.armar(
                new PeriodoEstadistico(LocalDate.parse("2026-03-01"), LocalDate.parse("2026-03-31")), contados);
    }

    @Test
    void conConsultasPeroSinCanceladasPorSocioElPorcentajeEsCero() {
        EstadisticaConsultaResponse r = armar(Map.of("AGENDADA", 2L, "CANCELADA_INSTITUCION", 5L));

        assertEquals(7, r.totalConsultas());
        assertEquals(0, r.canceladasPorSocio());
        assertEquals(0, r.porcentajeCancelacion().signum());
        assertEquals("0 %", r.porcentajeCancelacionTexto());
    }

    @Test
    void porcentajeParcialRedondeadoADosDecimalesSinContarLasCanceladasPorLaInstitucion() {
        EstadisticaConsultaResponse r = armar(Map.of(
                "AGENDADA", 1L, "CANCELADA_SOCIO", 1L, "CANCELADA_INSTITUCION", 1L));

        assertEquals(3, r.totalConsultas());
        assertEquals(1, r.canceladasPorSocio());
        assertEquals("33.33", r.porcentajeCancelacion().toPlainString());
        assertEquals("33.33 %", r.porcentajeCancelacionTexto());
    }

    @Test
    void porcentajeCienPorCiento() {
        EstadisticaConsultaResponse r = armar(Map.of("CANCELADA_SOCIO", 4L));

        assertEquals("100 %", r.porcentajeCancelacionTexto());
        assertEquals(4, r.totalConsultas());
    }

    @Test
    void elTotalSumaLosSieteEstados() {
        EstadisticaConsultaResponse r = armar(Map.of(
                "AGENDADA", 1L, "ATENDIDA", 2L, "CANCELADA_SOCIO", 3L, "CANCELADA_INSTITUCION", 4L,
                "NO_ASISTIO", 5L, "NO_ATENDIDA", 6L, "NO_SE_PRESENTO", 7L));

        assertEquals(28, r.totalConsultas());
        assertEquals("10.71 %", r.porcentajeCancelacionTexto());
    }

    @Test
    void fechasInvalidasSeRechazanSinConsultarLaBase() {
        EstadisticaConsultaService servicio = servicioA("2026-10-15T12:00:00Z");

        assertEquals("VALIDACION", assertThrows(ApiException.class,
                () -> servicio.calcular("15/03/2026", null)).getCode());
        assertThrows(ApiException.class, () -> servicio.calcular("2026-03-31", "2026-03-01"));
        assertThrows(ApiException.class, () -> servicio.calcular("2026-02-30", null));
        verifyNoInteractions(repository);
    }
}
