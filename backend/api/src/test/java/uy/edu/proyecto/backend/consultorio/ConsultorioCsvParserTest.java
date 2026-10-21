package uy.edu.proyecto.backend.consultorio;

import java.util.List;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ConsultorioCsvParserTest {

    private final ConsultorioCsvParser parser =
            new ConsultorioCsvParser();

    @Test
    void leeCsvSeparadoPorPuntoYComa() {
        String csv = """
                nombre;ubicacion
                Consultorio 1;Piso 1
                Consultorio 2;Piso 2
                """;

        List<ConsultorioCsvParser.Fila> filas = parser.leer(csv);

        assertEquals(2, filas.size());
        assertEquals(2, filas.get(0).numero());
        assertEquals("Consultorio 1", filas.get(0).nombre());
        assertEquals("Piso 2", filas.get(1).ubicacion());
        assertNull(filas.get(0).error());
    }

    @Test
    void leeCsvSeparadoPorComa() {
        String csv = """
                nombre,ubicacion
                Consultorio 3,Planta baja
                """;

        var filas = parser.leer(csv);

        assertEquals(1, filas.size());
        assertEquals("Consultorio 3", filas.get(0).nombre());
        assertEquals("Planta baja", filas.get(0).ubicacion());
    }

    @Test
    void eliminaBomInicial() {
        String csv = "\uFEFFnombre,ubicacion\n"
                + "Consultorio 4,Piso 3\n";

        var filas = parser.leer(csv);

        assertEquals(1, filas.size());
        assertEquals("Consultorio 4", filas.get(0).nombre());
    }

    @Test
    void interpretaSeparadoresEntreComillas() {
        String csv = """
                nombre;ubicacion
                Consultorio 5;"Piso 2; ala norte"
                """;

        var filas = parser.leer(csv);

        assertEquals(1, filas.size());
        assertEquals("Piso 2; ala norte", filas.get(0).ubicacion());
        assertNull(filas.get(0).error());
    }

    @Test
    void aceptaColumnasEnOrdenInvertido() {
        String csv = """
                ubicacion;nombre
                Piso 4;Consultorio 6
                """;

        var filas = parser.leer(csv);

        assertEquals("Consultorio 6", filas.get(0).nombre());
        assertEquals("Piso 4", filas.get(0).ubicacion());
    }

    @Test
    void rechazaEncabezadosIncorrectos() {
        String csv = """
                nombre;sector
                Consultorio 7;Piso 3
                """;

        IllegalArgumentException error = assertThrows(
                IllegalArgumentException.class,
                () -> parser.leer(csv)
        );

        assertTrue(error.getMessage().contains("nombre y ubicacion"));
    }

    @Test
    void identificaFilaIncompleta() {
        String csv = """
                nombre;ubicacion
                Consultorio 8
                """;

        var filas = parser.leer(csv);

        assertEquals(1, filas.size());
        assertEquals(2, filas.get(0).numero());
        assertNotNull(filas.get(0).error());
    }

    @Test
    void identificaColumnasExtra() {
        String csv = """
                nombre;ubicacion
                Consultorio 9;Piso 3;Extra
                """;

        var filas = parser.leer(csv);

        assertEquals(1, filas.size());
        assertNotNull(filas.get(0).error());
    }

    @Test
    void rechazaArchivoVacio() {
        assertThrows(
                IllegalArgumentException.class,
                () -> parser.leer("   ")
        );
    }
}
