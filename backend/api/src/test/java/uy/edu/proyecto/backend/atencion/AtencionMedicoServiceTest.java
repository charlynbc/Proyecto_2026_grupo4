package uy.edu.proyecto.backend.atencion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

class AtencionMedicoServiceTest {

    private AtencionMedicoRepository repository;
    private AtencionMedicoService service;

    @BeforeEach
    void setUp() {
        repository = mock(AtencionMedicoRepository.class);
        service = new AtencionMedicoService(repository);
    }

    private AtencionMedicaDTO atencion(long id) {
        return new AtencionMedicaDTO(
                id, LocalDate.of(2026, 10, 20),
                new AtencionMedicaDTO.PacienteRef(7L, "20000012", "Sofia", "Socia"),
                new Especialidad(9L, "Medicina General", false),
                "Afeccion", "Tratamiento", null, List.of());
    }

    @Test
    void listaConRangoObligatorioYOrdenPorDefecto() {
        when(repository.listar(5L, LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31),
                null, null, "fecha", "desc")).thenReturn(List.of(atencion(1L)));

        List<AtencionMedicaDTO> resultado = service.listar(
                5L, "2026-10-01", "2026-10-31", null, null, null, null);

        assertEquals(1, resultado.size());
        verify(repository).listar(5L, LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31),
                null, null, "fecha", "desc");
    }

    @Test
    void filtrosCombinadosSePropaganAlRepositorio() {
        when(repository.listar(5L, LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31),
                "socia", 9L, "apellido", "asc")).thenReturn(List.of());

        service.listar(5L, "2026-10-01", "2026-10-31", " socia ", "9", "apellido", null);

        verify(repository).listar(5L, LocalDate.of(2026, 10, 1), LocalDate.of(2026, 10, 31),
                "socia", 9L, "apellido", "asc");
    }

    @Test
    void fechasObligatorias() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, null, "2026-10-31", null, null, null, null));
        assertEquals("VALIDACION", error.getCode());
        error = assertThrows(ApiException.class,
                () -> service.listar(5L, "2026-10-01", "", null, null, null, null));
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void fechaConFormatoInvalidoDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, "31/10/2026", "2026-10-31", null, null, null, null));
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void fechaDesdePosteriorAHastaDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, "2026-10-31", "2026-10-01", null, null, null, null));
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void especialidadInvalidaDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, "2026-10-01", "2026-10-31", null, "-3", null, null));
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void ordenInvalidoDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, "2026-10-01", "2026-10-31", null, null, "ci", null));
        assertEquals("ORDEN_INVALIDO", error.getCode());
    }

    @Test
    void sentidoInvalidoDevuelve400() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.listar(5L, "2026-10-01", "2026-10-31", null, null, "fecha",
                        "diagonal"));
        assertEquals("SENTIDO_INVALIDO", error.getCode());
    }

    @Test
    void detallePropioDevuelveLaAtencion() {
        when(repository.obtenerDetallePropio(5L, 1L)).thenReturn(atencion(1L));

        AtencionMedicaDTO resultado = service.detalle(5L, 1L);

        assertEquals(1L, resultado.idAtencion());
        assertEquals("20000012", resultado.paciente().ci());
    }

    @Test
    void detalleAjenoOInexistenteDevuelve404() {
        when(repository.obtenerDetallePropio(5L, 99L)).thenReturn(null);

        ApiException error = assertThrows(ApiException.class, () -> service.detalle(5L, 99L));

        assertEquals("NO_ENCONTRADO", error.getCode());
        assertEquals(404, error.getStatus().value());
    }

    @Test
    void detalleConIdentificadorInvalidoDevuelve400() {
        ApiException error = assertThrows(ApiException.class, () -> service.detalle(5L, 0L));
        assertEquals("VALIDACION", error.getCode());
    }
}
