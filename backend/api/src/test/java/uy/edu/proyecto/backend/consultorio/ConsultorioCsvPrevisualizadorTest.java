package uy.edu.proyecto.backend.consultorio;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ConsultorioCsvPrevisualizadorTest {

    private final ConsultorioCsvPrevisualizador previsualizador =
            new ConsultorioCsvPrevisualizador();

    @Test
    void previsualizaTodasLasFilasValidas() {
        String csv = """
                nombre;ubicacion
                Consultorio 1;Piso 1
                Consultorio 2;Piso 2
                """;

        var resultado = previsualizador.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(2, resultado.validas());
        assertEquals(0, resultado.invalidas());
        assertEquals(2, resultado.filas().size());
        assertTrue(resultado.errores().isEmpty());
    }

    @Test
    void identificaFilasValidasEInvalidas() {
        String csv = """
                nombre;ubicacion
                Consultorio 1;Piso 1
                consultorio 1;Piso 2
                Consultorio 3;
                """;

        var resultado = previsualizador.previsualizar(csv);

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

        var resultado = previsualizador.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(1, resultado.validas());
        assertEquals(1, resultado.invalidas());
        assertTrue(resultado.errores().get(0).error()
                .contains("exactamente 2 columnas"));
    }

    @Test
    void filaInvalidaNoReservaNombre() {
        String csv = """
                nombre;ubicacion
                Consultorio 4;
                consultorio 4;Piso 2
                """;

        var resultado = previsualizador.previsualizar(csv);

        assertEquals(2, resultado.total());
        assertEquals(1, resultado.validas());
        assertEquals(1, resultado.invalidas());
        assertFalse(resultado.filas().get(0).valida());
        assertTrue(resultado.filas().get(1).valida());
    }

    @Test
    void archivoSoloConEncabezadosDevuelveCeroFilas() {
        String csv = """
                nombre;ubicacion
                """;

        var resultado = previsualizador.previsualizar(csv);

        assertEquals(0, resultado.total());
        assertEquals(0, resultado.validas());
        assertEquals(0, resultado.invalidas());
        assertTrue(resultado.filas().isEmpty());
        assertTrue(resultado.errores().isEmpty());
    }

    @Test
    void rechazaArchivoCompletamenteVacio() {
        assertThrows(
                IllegalArgumentException.class,
                () -> previsualizador.previsualizar("   ")
        );
    }
}
