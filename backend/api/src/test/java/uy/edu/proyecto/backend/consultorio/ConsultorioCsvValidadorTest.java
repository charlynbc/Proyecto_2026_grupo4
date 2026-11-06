package uy.edu.proyecto.backend.consultorio;

import java.util.List;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.csv.CsvArchivo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ConsultorioCsvValidadorTest {

    private final ConsultorioCsvValidador validador =
            new ConsultorioCsvValidador();

    private CsvArchivo.FilaCruda fila(
            int numero,
            String nombre,
            String ubicacion
    ) {
        return new CsvArchivo.FilaCruda(
                numero,
                java.util.Arrays.asList(nombre, ubicacion),
                null
        );
    }

    @Test
    void aceptaFilaValida() {
        var resultado = validador.validar(List.of(
                fila(2, "Consultorio 1", "Piso 1")
        ));

        assertEquals(1, resultado.size());
        assertTrue(resultado.get(0).valida());
        assertNull(resultado.get(0).error());
    }

    @Test
    void normalizaEspacios() {
        var resultado = validador.validar(List.of(
                fila(2, "  Consultorio 1  ", "  Piso 1  ")
        ));

        assertEquals("Consultorio 1", resultado.get(0).nombre());
        assertEquals("Piso 1", resultado.get(0).ubicacion());
        assertTrue(resultado.get(0).valida());
    }

    @Test
    void rechazaNombreVacio() {
        var resultado = validador.validar(List.of(
                fila(2, "   ", "Piso 1")
        ));

        assertFalse(resultado.get(0).valida());
        assertEquals("El nombre es obligatorio", resultado.get(0).error());
    }

    @Test
    void rechazaNombreNulo() {
        var resultado = validador.validar(List.of(
                fila(2, null, "Piso 1")
        ));

        assertFalse(resultado.get(0).valida());
    }

    @Test
    void rechazaUbicacionVacia() {
        var resultado = validador.validar(List.of(
                fila(2, "Consultorio 1", "  ")
        ));

        assertFalse(resultado.get(0).valida());
        assertEquals("La ubicación es obligatoria", resultado.get(0).error());
    }

    @Test
    void rechazaUbicacionNula() {
        var resultado = validador.validar(List.of(
                fila(2, "Consultorio 1", null)
        ));

        assertFalse(resultado.get(0).valida());
    }

    @Test
    void rechazaNombreMayorA120Caracteres() {
        var resultado = validador.validar(List.of(
                fila(2, "A".repeat(121), "Piso 1")
        ));

        assertFalse(resultado.get(0).valida());
        assertEquals(
                "El nombre supera 120 caracteres",
                resultado.get(0).error()
        );
    }

    @Test
    void rechazaUbicacionMayorA200Caracteres() {
        var resultado = validador.validar(List.of(
                fila(2, "Consultorio 1", "B".repeat(201))
        ));

        assertFalse(resultado.get(0).valida());
    }

    @Test
    void aceptaLongitudesMaximas() {
        var resultado = validador.validar(List.of(
                fila(2, "A".repeat(120), "B".repeat(200))
        ));

        assertTrue(resultado.get(0).valida());
    }

    @Test
    void detectaDuplicadosSinDistinguirMayusculas() {
        var resultado = validador.validar(List.of(
                fila(2, "Consultorio 1", "Piso 1"),
                fila(3, "consultorio 1", "Piso 2")
        ));

        assertTrue(resultado.get(0).valida());
        assertFalse(resultado.get(1).valida());
        assertTrue(resultado.get(1).error().contains("fila 2"));
    }

    @Test
    void filaInvalidaNoReservaNombre() {
        var resultado = validador.validar(List.of(
                fila(2, "Consultorio 1", ""),
                fila(3, "Consultorio 1", "Piso 2")
        ));

        assertFalse(resultado.get(0).valida());
        assertTrue(resultado.get(1).valida());
    }

    @Test
    void conservaErrorDetectadoPorParser() {
        var filaConError = new CsvArchivo.FilaCruda(
                4,
                List.of(),
                "La fila debe tener exactamente 2 columnas"
        );

        var resultado = validador.validar(List.of(filaConError));

        assertFalse(resultado.get(0).valida());
        assertEquals(
                "La fila debe tener exactamente 2 columnas",
                resultado.get(0).error()
        );
    }
}
