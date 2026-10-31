package uy.edu.proyecto.backend.pase;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.atencion.AtencionMedicaDTO;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

class PaseMedicoServiceTest {

    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-10-30T12:00:00Z"), ZoneId.of("America/Montevideo"));

    private PaseMedicoRepository repository;
    private PaseMedicoService service;

    @BeforeEach
    void setUp() {
        repository = mock(PaseMedicoRepository.class);
        service = new PaseMedicoService(repository, RELOJ);
    }

    private PaseEmitidoDTO pase(long id, String situacion) {
        return new PaseEmitidoDTO(
                id,
                new AtencionMedicaDTO.PacienteRef(7L, "20000012", "Sofia", "Socia"),
                new Especialidad(4L, "Cardiologia", true),
                OffsetDateTime.parse("2026-10-20T09:41:00-03:00"),
                LocalDate.of(2027, 1, 18),
                situacion);
    }

    @Test
    void listaConOrdenPorDefectoVencimientoAscendente() {
        when(repository.listarEmitidos(5L, null, "vencimiento", "asc",
                LocalDate.of(2026, 10, 30)))
                .thenReturn(List.of(pase(1L, "DISPONIBLE"), pase(2L, "UTILIZADO")));

        List<PaseEmitidoDTO> resultado = service.listar(5L, null, null, null);

        assertEquals(2, resultado.size());
        verify(repository).listarEmitidos(5L, null, "vencimiento", "asc",
                LocalDate.of(2026, 10, 30));
    }

    @Test
    void filtroPorSituacionYOrdenPorEmisionSePropagan() {
        when(repository.listarEmitidos(5L, "VENCIDO", "emision", "desc",
                LocalDate.of(2026, 10, 30))).thenReturn(List.of());

        service.listar(5L, "vencido", "emision", "desc");

        verify(repository).listarEmitidos(5L, "VENCIDO", "emision", "desc",
                LocalDate.of(2026, 10, 30));
    }

    @Test
    void situacionInvalidaDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, "CANCELADO", null, null));
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void ordenInvalidoDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, null, "paciente", null));
        assertEquals("ORDEN_INVALIDO", error.getCode());
    }

    @Test
    void sentidoInvalidoDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, null, "emision", "diagonal"));
        assertEquals("SENTIDO_INVALIDO", error.getCode());
    }

    @Test
    void medicoInvalidoDevuelve401() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(0L, null, null, null));
        assertEquals("TOKEN_INVALIDO", error.getCode());
    }
}
