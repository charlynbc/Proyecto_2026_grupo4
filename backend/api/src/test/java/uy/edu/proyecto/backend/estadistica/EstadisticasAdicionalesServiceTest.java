package uy.edu.proyecto.backend.estadistica;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

class EstadisticasAdicionalesServiceTest {
    private static final Clock RELOJ = Clock.fixed(Instant.parse("2026-11-07T12:00:00Z"),
            ZoneId.of("America/Montevideo"));

    @Test
    void inasistenciaNoCuentaNoAtendidaEnNumerador() {
        var repository = mock(EstadisticaInasistenciaRepository.class);
        when(repository.contar(any(), any(), any(), eq(false))).thenReturn(List.of(
                new EstadisticaInasistenciaRepository.Fila(1, "General", null, 1, 1, 0, 2)));
        var respuesta = new EstadisticaInasistenciaService(repository, RELOJ)
                .calcular(null, null, null);
        assertEquals(LocalDate.of(2026, 11, 1), respuesta.desde());
        assertEquals("ESPECIALIDAD", respuesta.agruparPor());
        assertEquals(4, respuesta.items().getFirst().total());
        assertEquals("25 %", respuesta.items().getFirst().inasistencia());
    }

    @Test
    void pasesSinResueltosDevuelveSinDatosAunqueHayaDisponibles() {
        var repository = mock(EstadisticaPaseRepository.class);
        when(repository.contar(any(), any(), any(), eq(null))).thenReturn(List.of(
                new EstadisticaPaseRepository.Fila(
                        new Especialidad(1L, "General", false), 2, 0, 2, 0)));
        var fila = new EstadisticaPaseService(repository, RELOJ)
                .calcular(null, null, null).items().getFirst();
        assertNull(fila.porcentajeUtilizados());
        assertEquals("Sin datos", fila.utilizacion());
    }

    @Test
    void franjasCompletanLas168CeldasConCeros() {
        var repository = mock(EstadisticaFranjaRepository.class);
        when(repository.contar(any(), any(), eq("CONSULTAS"), eq(null))).thenReturn(List.of(
                new EstadisticaFranjaRepository.Fila(2, 10, 3)));
        var respuesta = new EstadisticaFranjaService(repository, RELOJ)
                .calcular(null, null, null, null);
        assertEquals(168, respuesta.celdas().size());
        assertEquals(3, respuesta.celdas().get(34).cantidad());
        assertEquals(0, respuesta.celdas().get(35).cantidad());
    }

    @Test
    void idsInvalidosTienenErrorUniforme() {
        for (String valor : List.of("abc", "0", "-2")) {
            assertEquals("VALIDACION", assertThrows(ApiException.class,
                    () -> IdFiltroEstadistico.resolver(valor, "especialidadId")).getCode());
        }
    }
}
