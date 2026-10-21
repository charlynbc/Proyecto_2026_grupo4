package uy.edu.proyecto.backend.consultorio;

import java.util.List;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class ConsultorioImportacionServiceTest {

    private final ConsultorioRepository repository =
            mock(ConsultorioRepository.class);

    private final ConsultorioImportacionService service =
            new ConsultorioImportacionService(repository);

    @Test
    void aceptaConsultoriosQueNoExisten() {
        when(repository.listar()).thenReturn(List.of());

        String csv = """
                nombre;ubicacion
                Consultorio 1;Piso 1
                Consultorio 2;Piso 2
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(2, resultado.validas());
        assertEquals(0, resultado.invalidas());

        verify(repository).listar();
    }

    @Test
    void detectaDuplicadoExistente() {
        when(repository.listar()).thenReturn(List.of(
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

        verify(repository).listar();
    }

    @Test
    void detectaDuplicadoIgnorandoMayusculasYEspacios() {
        when(repository.listar()).thenReturn(List.of(
                new Consultorio(1L, "  CONSULTORIO 7  ", "Piso 1")
        ));

        String csv = """
                nombre;ubicacion
                consultorio 7;Piso 3
                """;

        var resultado = service.previsualizar(csv);

        assertEquals(0, resultado.validas());
        assertEquals(1, resultado.invalidas());

        verify(repository).listar();
    }

    @Test
    void recalculaResumenConFilasMixtas() {
        when(repository.listar()).thenReturn(List.of(
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

        verify(repository).listar();
    }

    @Test
    void conservaErroresDelParser() {
        when(repository.listar()).thenReturn(List.of());

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

        verify(repository).listar();
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
}
