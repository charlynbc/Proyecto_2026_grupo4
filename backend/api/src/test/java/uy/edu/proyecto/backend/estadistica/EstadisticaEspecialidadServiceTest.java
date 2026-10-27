package uy.edu.proyecto.backend.estadistica;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class EstadisticaEspecialidadServiceTest {

    private static final ZoneId MONTEVIDEO = ZoneId.of("America/Montevideo");

    private final EstadisticaEspecialidadRepository repository =
            mock(EstadisticaEspecialidadRepository.class);

    private EstadisticaEspecialidadService servicioA(String instanteUtc) {
        return new EstadisticaEspecialidadService(
                repository,
                Clock.fixed(Instant.parse(instanteUtc), MONTEVIDEO)
        );
    }

    @Test
    void sinParametrosUsaElMesEnCursoCompleto() {
        when(repository.contarAgendadas(any(), any())).thenReturn(List.of());

        EstadisticaEspecialidadResponse respuesta =
                servicioA("2026-10-15T12:00:00Z").calcular(null, null);

        assertEquals("2026-10-01", respuesta.desde().toString());
        assertEquals("2026-10-31", respuesta.hasta().toString());
        verify(repository).contarAgendadas(
                Instant.parse("2026-10-01T03:00:00Z"),
                Instant.parse("2026-11-01T03:00:00Z")
        );
    }

    @Test
    void elMesEnCursoSeCalculaEnMontevideoYNoEnUtc() {
        // 2026-11-01T01:30Z es todavia 2026-10-31 22:30 en Montevideo.
        when(repository.contarAgendadas(any(), any())).thenReturn(List.of());

        EstadisticaEspecialidadResponse respuesta =
                servicioA("2026-11-01T01:30:00Z").calcular("", " ");

        assertEquals("2026-10-01", respuesta.desde().toString());
        assertEquals("2026-10-31", respuesta.hasta().toString());
    }

    @Test
    void rangoExplicitoSeConvierteALimitesDeDiaEnMontevideoConFinExclusivo() {
        when(repository.contarAgendadas(any(), any())).thenReturn(List.of());

        servicioA("2026-10-15T12:00:00Z").calcular("2026-03-01", "2026-03-31");

        verify(repository).contarAgendadas(
                Instant.parse("2026-03-01T03:00:00Z"),
                Instant.parse("2026-04-01T03:00:00Z")
        );
    }

    @Test
    void unDiaUnicoEsUnRangoValido() {
        when(repository.contarAgendadas(any(), any())).thenReturn(List.of());

        servicioA("2026-10-15T12:00:00Z").calcular("2026-03-10", "2026-03-10");

        verify(repository).contarAgendadas(
                Instant.parse("2026-03-10T03:00:00Z"),
                Instant.parse("2026-03-11T03:00:00Z")
        );
    }

    @Test
    void soloDesdeCompletaElFinDelMesEnCurso() {
        when(repository.contarAgendadas(any(), any())).thenReturn(List.of());

        EstadisticaEspecialidadResponse respuesta =
                servicioA("2026-10-15T12:00:00Z").calcular("2026-10-10", null);

        assertEquals("2026-10-10", respuesta.desde().toString());
        assertEquals("2026-10-31", respuesta.hasta().toString());
    }

    @Test
    void devuelveLosItemsDelRepositorioSinModificarlos() {
        List<EstadisticaEspecialidadDTO> items = List.of(
                new EstadisticaEspecialidadDTO(new Especialidad(1L, "Medicina General", false), 5),
                new EstadisticaEspecialidadDTO(new Especialidad(2L, "Pediatria", true), 0)
        );
        when(repository.contarAgendadas(any(), any())).thenReturn(items);

        EstadisticaEspecialidadResponse respuesta =
                servicioA("2026-10-15T12:00:00Z").calcular(null, null);

        assertEquals(items, respuesta.items());
    }

    @Test
    void rangoInvertidoDevuelve400SinConsultarLaBase() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> servicioA("2026-10-15T12:00:00Z").calcular("2026-03-31", "2026-03-01")
        );

        assertEquals(400, error.getStatus().value());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void formatosInvalidosYTextoMaliciosoDevuelven400SinConsultarLaBase() {
        EstadisticaEspecialidadService servicio = servicioA("2026-10-15T12:00:00Z");

        for (String invalido : List.of(
                "31/03/2026",
                "2026-13-01",
                "2026-02-30",
                "ayer",
                "2026-03-01' OR '1'='1",
                "2026-03-01; DROP TABLE consulta;--"
        )) {
            assertThrows(ApiException.class, () -> servicio.calcular(invalido, null), invalido);
            assertThrows(ApiException.class, () -> servicio.calcular(null, invalido), invalido);
        }
        verifyNoInteractions(repository);
    }
}
