package uy.edu.proyecto.backend.consultorio;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class ConsultorioImportacionServiceTest {

    private final ConsultorioRepository repository =
            mock(ConsultorioRepository.class);
    private final ConsultorioService consultorioService =
            mock(ConsultorioService.class);

    private final ConsultorioImportacionService service =
            new ConsultorioImportacionService(repository, consultorioService);

    @Test
    void aceptaConsultoriosQueNoExisten() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of());

        String csv = """
                nombre;ubicacion
                Consultorio 1;Piso 1
                Consultorio 2;Piso 2
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(2, resultado.validas());
        assertEquals(0, resultado.invalidas());

        verify(repository).buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet());
    }

    @Test
    void detectaDuplicadoExistente() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of(
                        "consultorio 1",
                        new Consultorio(1L, "Consultorio 1", "Piso 1")
                ));

        String csv = """
                nombre;ubicacion
                Consultorio 1;Piso 3
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(1, resultado.total());
        assertEquals(0, resultado.validas());
        assertEquals(1, resultado.invalidas());
        assertEquals(
                "El consultorio ya existe en el sistema",
                resultado.errores().get(0).error()
        );
    }

    @Test
    void detectaDuplicadoIgnorandoMayusculas() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of(
                        "consultorio 7",
                        new Consultorio(1L, "CONSULTORIO 7", "Piso 1")
                ));

        String csv = """
                nombre;ubicacion
                consultorio 7;Piso 3
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(0, resultado.validas());
        assertEquals(1, resultado.invalidas());
    }

    @Test
    void recalculaResumenConFilasMixtas() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of(
                        "consultorio 1",
                        new Consultorio(1L, "Consultorio 1", "Piso 1")
                ));

        String csv = """
                nombre;ubicacion
                Consultorio 2;Piso 2
                Consultorio 1;Piso 3
                Consultorio 4;
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(3, resultado.total());
        assertEquals(1, resultado.validas());
        assertEquals(2, resultado.invalidas());
        assertEquals(2, resultado.errores().size());
        assertEquals(3, resultado.errores().get(0).numero());
        assertEquals(4, resultado.errores().get(1).numero());
    }

    @Test
    void conservaErroresDelParser() {
        String csv = """
                nombre;ubicacion
                Consultorio 1;Piso 1;Extra
                Consultorio 2;Piso 2
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(1, resultado.validas());
        assertEquals(1, resultado.invalidas());
        assertTrue(resultado.errores().get(0).error()
                .contains("exactamente 2 columnas"));
    }

    @Test
    void noConsultaBaseSiTodasLasFilasSonInvalidas() {
        String csv = """
                nombre;ubicacion
                Consultorio 1;
                ;Piso 2
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(0, resultado.validas());
        assertEquals(2, resultado.invalidas());

        verifyNoInteractions(repository);
    }

    @Test
    void noConsultaBaseSiArchivoNoTieneRegistros() {
        String csv = """
                nombre;ubicacion
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(0, resultado.total());
        assertEquals(0, resultado.validas());
        assertEquals(0, resultado.invalidas());

        verifyNoInteractions(repository);
    }

    @Test
    void confirmarImportaSoloLasFilasValidas() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of());
        when(consultorioService.crear("Consultorio 1", "Piso 1"))
                .thenReturn(new Consultorio(1L, "Consultorio 1", "Piso 1"));

        String csv = """
                nombre,ubicacion
                Consultorio 1,Piso 1
                Consultorio 2,
                """;

        var resultado = service.confirmar(csv);

        assertEquals(2, resultado.total());
        assertEquals(1, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertEquals(3, resultado.errores().get(0).numero());

        verify(consultorioService).crear("Consultorio 1", "Piso 1");
        verify(consultorioService, times(1)).crear(anyString(), anyString());
    }

    @Test
    void confirmarRechazaDuplicadoDelArchivoYConservaLaPrimeraAparicion() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of());
        when(consultorioService.crear("Consultorio 1", "Piso 1"))
                .thenReturn(new Consultorio(1L, "Consultorio 1", "Piso 1"));

        String csv = """
                nombre,ubicacion
                Consultorio 1,Piso 1
                CONSULTORIO 1,Piso 9
                """;

        var resultado = service.confirmar(csv);

        assertEquals(1, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertTrue(resultado.errores().get(0).error().contains("fila 2"));

        verify(consultorioService).crear("Consultorio 1", "Piso 1");
    }

    @Test
    void confirmarRechazaExistenteSinInvocarElAlta() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of(
                        "consultorio 1",
                        new Consultorio(1L, "Consultorio 1", "Piso 1")
                ));

        String csv = """
                nombre,ubicacion
                Consultorio 1,Piso 3
                """;

        var resultado = service.confirmar(csv);

        assertEquals(0, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertEquals(
                "El consultorio ya existe en el sistema",
                resultado.errores().get(0).error()
        );

        verifyNoInteractions(consultorioService);
    }

    @Test
    void confirmarRechazaLaFilaSiElAltaFallaPorConcurrencia() {
        when(repository.buscarPorNombresLower(org.mockito.ArgumentMatchers.anySet()))
                .thenReturn(Map.of());
        when(consultorioService.crear("Consultorio 1", "Piso 1"))
                .thenThrow(new ApiException(
                        HttpStatus.CONFLICT,
                        "CONSULTORIO_DUPLICADO",
                        "Ya existe un consultorio registrado con ese nombre."
                ));

        String csv = """
                nombre,ubicacion
                Consultorio 1,Piso 1
                """;

        var resultado = service.confirmar(csv);

        assertEquals(0, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertEquals(
                "Ya existe un consultorio registrado con ese nombre.",
                resultado.errores().get(0).error()
        );
    }
}
