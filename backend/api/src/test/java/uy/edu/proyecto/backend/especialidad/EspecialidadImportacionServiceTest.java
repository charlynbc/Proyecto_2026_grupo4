package uy.edu.proyecto.backend.especialidad;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class EspecialidadImportacionServiceTest {

    private final EspecialidadRepository repository =
            mock(EspecialidadRepository.class);
    private final EspecialidadService especialidadService =
            mock(EspecialidadService.class);

    private final EspecialidadImportacionService service =
            new EspecialidadImportacionService(repository, especialidadService);

    @Test
    void previsualizaCsvValidoSinExistentes() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of());

        String csv = """
                nombre,requiere_pase
                Cardiologia,si
                Pediatria,no
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(2, resultado.validas());
        assertEquals(0, resultado.invalidas());
        assertTrue(resultado.errores().isEmpty());
    }

    @Test
    void previsualizacionMarcaEspecialidadExistenteEnBase() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of(
                        "cardiologia",
                        new Especialidad(1L, "Cardiologia", true)
                ));

        String csv = """
                nombre,requiere_pase
                Cardiologia,no
                Pediatria,no
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(1, resultado.validas());
        assertEquals(1, resultado.invalidas());
        assertEquals(
                "La especialidad ya existe en el sistema",
                resultado.errores().get(0).error()
        );
    }

    @Test
    void previsualizacionNoConsultaBaseSiNoHayFilasValidas() {
        String csv = """
                nombre,requiere_pase
                ,si
                Cardiologia,quizas
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(0, resultado.validas());
        assertEquals(2, resultado.invalidas());
        verifyNoInteractions(repository);
    }

    @Test
    void confirmarInsertaSoloLasFilasValidas() {
        when(especialidadService.crear(anyString(), anyBoolean()))
                .thenAnswer(invocacion -> new Especialidad(
                        1L,
                        invocacion.getArgument(0),
                        invocacion.getArgument(1)
                ));

        String csv = """
                nombre,requiere_pase
                Cardiologia,si
                ,no
                Pediatria,no
                """;

        var resultado = service.confirmar(csv);

        assertEquals(3, resultado.total());
        assertEquals(2, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertEquals(1, resultado.errores().size());
        assertEquals(3, resultado.errores().get(0).numero());

        verify(especialidadService).crear("Cardiologia", true);
        verify(especialidadService).crear("Pediatria", false);
        verify(especialidadService, never()).crear(eq(""), anyBoolean());
    }

    @Test
    void confirmarRechazaDuplicadoDetectadoPorElAltaIndividual() {
        when(especialidadService.crear(eq("Cardiologia"), anyBoolean()))
                .thenThrow(new ApiException(
                        HttpStatus.CONFLICT,
                        "ESPECIALIDAD_DUPLICADA",
                        "Ya existe una especialidad registrada con ese nombre."
                ));
        when(especialidadService.crear(eq("Pediatria"), anyBoolean()))
                .thenReturn(new Especialidad(2L, "Pediatria", false));

        String csv = """
                nombre,requiere_pase
                Cardiologia,si
                Pediatria,no
                """;

        var resultado = service.confirmar(csv);

        assertEquals(2, resultado.total());
        assertEquals(1, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertEquals(
                "Ya existe una especialidad registrada con ese nombre.",
                resultado.errores().get(0).error()
        );
        assertNull(resultado.filas().get(1).error());
    }

    @Test
    void confirmarRechazaDuplicadosDentroDelArchivoSinLlamarAlAlta() {
        String csv = """
                nombre,requiere_pase
                Cardiologia,si
                CARDIOLOGIA,no
                """;

        var resultado = service.confirmar(csv);

        assertEquals(2, resultado.total());
        assertEquals(1, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        verify(especialidadService).crear("Cardiologia", true);
        verify(especialidadService, never()).crear(eq("CARDIOLOGIA"), anyBoolean());
    }
}
