package uy.edu.proyecto.backend.especialidad;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.csv.CsvArchivo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class EspecialidadCsvValidadorTest {

    private final EspecialidadCsvValidador validador =
            new EspecialidadCsvValidador();

    private java.util.List<FilaEspecialidadCsv> validar(String csv) {
        return validador.validar(
                CsvArchivo.parsear(csv, EspecialidadCsvValidador.COLUMNAS)
        );
    }

    @Test
    void aceptaFilasValidas() {
        var filas = validar("""
                nombre,requiere_pase
                Cardiologia,si
                Pediatria,no
                """);

        assertEquals(2, filas.size());
        assertTrue(filas.get(0).valida());
        assertEquals(Boolean.TRUE, filas.get(0).requierePase());
        assertTrue(filas.get(1).valida());
        assertEquals(Boolean.FALSE, filas.get(1).requierePase());
    }

    @Test
    void aceptaSiConTildeYMayusculas() {
        var filas = validar("""
                nombre,requiere_pase
                Cardiologia,SÍ
                Pediatria,NO
                """);

        assertEquals(Boolean.TRUE, filas.get(0).requierePase());
        assertEquals(Boolean.FALSE, filas.get(1).requierePase());
    }

    @Test
    void rechazaNombreVacio() {
        var filas = validar("""
                nombre,requiere_pase
                ,si
                """);

        assertFalse(filas.get(0).valida());
        assertEquals("El nombre es obligatorio", filas.get(0).error());
    }

    @Test
    void rechazaNombreLargo() {
        var filas = validar("nombre,requiere_pase\n"
                + "X".repeat(121) + ",si\n");

        assertFalse(filas.get(0).valida());
        assertTrue(filas.get(0).error().contains("120"));
    }

    @Test
    void rechazaRequierePaseInvalidoOVacio() {
        var filas = validar("""
                nombre,requiere_pase
                Cardiologia,quizas
                Pediatria,
                """);

        assertEquals("requiere_pase debe ser si o no", filas.get(0).error());
        assertTrue(filas.get(1).error().contains("obligatoria"));
    }

    @Test
    void detectaDuplicadosEnArchivoSinDistinguirMayusculas() {
        var filas = validar("""
                nombre,requiere_pase
                Cardiologia,si
                CARDIOLOGIA,no
                cardiologia,si
                """);

        assertTrue(filas.get(0).valida());
        assertFalse(filas.get(1).valida());
        assertFalse(filas.get(2).valida());
        assertTrue(filas.get(1).error().contains("fila 2"));
    }

    @Test
    void propagaErroresDeFormatoDelParser() {
        var filas = validar("""
                nombre,requiere_pase
                Cardiologia,si,extra
                """);

        assertFalse(filas.get(0).valida());
        assertTrue(filas.get(0).error().contains("columnas"));
        assertNull(filas.get(0).nombre());
    }
}
