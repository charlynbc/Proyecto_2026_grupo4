package uy.edu.proyecto.backend.estadistica;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class EstadisticaTurnoServiceTest {

    private static final ZoneId MONTEVIDEO = ZoneId.of("America/Montevideo");

    private final EstadisticaTurnoRepository repository = mock(EstadisticaTurnoRepository.class);

    private EstadisticaTurnoService servicioA(String instanteUtc) {
        return new EstadisticaTurnoService(
                repository, Clock.fixed(Instant.parse(instanteUtc), MONTEVIDEO));
    }

    private static EstadisticaTurnoRepository.Fila fila(long ofrecidos, long ocupados) {
        return new EstadisticaTurnoRepository.Fila(
                1,
                new EstadisticaTurnoDTO.Persona(2, "Marta", "Medica"),
                new Especialidad(1L, "Medicina General", false),
                new EstadisticaTurnoDTO.Consultorio(3, "Consultorio 1", "Planta baja"),
                3, 1, ofrecidos, ocupados);
    }

    @Test
    void sinParametrosUsaElMesEnCurso() {
        when(repository.contarUtilizacion(eq(LocalDate.parse("2026-10-01")), eq(LocalDate.parse("2026-10-31")), any(Instant.class)))
                .thenReturn(List.of());

        EstadisticaTurnoResponse r = servicioA("2026-10-15T12:00:00Z").calcular(null, null);

        assertEquals(LocalDate.parse("2026-10-01"), r.desde());
        assertEquals(LocalDate.parse("2026-10-31"), r.hasta());
        assertEquals(0, r.items().size());
    }

    @Test
    void elMesEnCursoSeCalculaEnMontevideoYNoEnUtc() {
        // 2026-11-01T01:30Z es todavia 31 de octubre en Montevideo.
        when(repository.contarUtilizacion(eq(LocalDate.parse("2026-10-01")), eq(LocalDate.parse("2026-10-31")), any(Instant.class)))
                .thenReturn(List.of());

        EstadisticaTurnoResponse r = servicioA("2026-11-01T01:30:00Z").calcular("", " ");

        assertEquals(LocalDate.parse("2026-10-31"), r.hasta());
    }

    @Test
    void rangoExplicitoSeDelegaTalCual() {
        when(repository.contarUtilizacion(eq(LocalDate.parse("2026-03-01")), eq(LocalDate.parse("2026-03-01")), any(Instant.class)))
                .thenReturn(List.of());

        servicioA("2026-10-15T12:00:00Z").calcular("2026-03-01", "2026-03-01");

        verify(repository).contarUtilizacion(
                LocalDate.parse("2026-03-01"), LocalDate.parse("2026-03-01"),
                Instant.parse("2026-10-15T12:00:00Z"));
    }

    @Test
    void fechasInvalidasYRangoInvertidoDan400SinConsultarLaBase() {
        EstadisticaTurnoService servicio = servicioA("2026-10-15T12:00:00Z");

        for (String[] par : new String[][] {
                {"2026-13-01", null}, {null, "31/03/2026"}, {"2026-03-31", "2026-03-01"}}) {
            ApiException e = assertThrows(ApiException.class, () -> servicio.calcular(par[0], par[1]));
            assertEquals(400, e.getStatus().value());
            assertEquals("VALIDACION", e.getCode());
        }
        verifyNoInteractions(repository);
    }

    @Test
    void ocupacionParcialTotalYCero() {
        assertEquals("25 %", EstadisticaTurnoService.aDto(fila(8, 2)).utilizacion());
        assertEquals("100 %", EstadisticaTurnoService.aDto(fila(8, 8)).utilizacion());
        EstadisticaTurnoDTO cero = EstadisticaTurnoService.aDto(fila(8, 0));
        assertEquals("0 %", cero.utilizacion());
        assertEquals(0, cero.porcentajeUtilizacion().signum());
    }

    @Test
    void divisionPorCeroEsSinDatosYNoCeroPorCiento() {
        EstadisticaTurnoDTO dto = EstadisticaTurnoService.aDto(fila(0, 0));

        assertEquals("Sin datos", dto.utilizacion());
        assertNull(dto.porcentajeUtilizacion());
    }

    @Test
    void redondeaADosDecimales() {
        EstadisticaTurnoDTO dto = EstadisticaTurnoService.aDto(fila(3, 1));

        assertEquals("33.33", dto.porcentajeUtilizacion().toPlainString());
        assertEquals("33.33 %", dto.utilizacion());
    }
}
