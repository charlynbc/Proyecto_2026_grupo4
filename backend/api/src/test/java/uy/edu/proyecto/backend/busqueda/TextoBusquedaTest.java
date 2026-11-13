package uy.edu.proyecto.backend.busqueda;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class TextoBusquedaTest {

    @Test
    void quitaLaTildeYPasaAMinusculas() {
        assertEquals("perez", TextoBusqueda.normalizar("Pérez"));
    }

    @Test
    void lasMayusculasAcentuadasTambienSeNormalizan() {
        assertEquals("perez", TextoBusqueda.normalizar("PÉREZ"));
    }

    @Test
    void sinTildeNiMayusculaQuedaIgual() {
        assertEquals("perez", TextoBusqueda.normalizar("perez"));
    }

    @Test
    void todasLasVocalesConTildeYLaUConDieresis() {
        assertEquals("aeiouu", TextoBusqueda.normalizar("áéíóúü"));
        assertEquals("aeiouu", TextoBusqueda.normalizar("ÁÉÍÓÚÜ"));
    }

    @Test
    void laEnieSeConservaComoLetraDistinta() {
        assertEquals("muñoz", TextoBusqueda.normalizar("Muñoz"));
        assertEquals("muñoz", TextoBusqueda.normalizar("MUÑOZ"));
    }

    @Test
    void vacioYEspaciosDanVacio() {
        assertEquals("", TextoBusqueda.normalizar(""));
        assertEquals("", TextoBusqueda.normalizar("   "));
        assertEquals("", TextoBusqueda.normalizar(null));
    }

    @Test
    void losEspaciosDeLosExtremosSeQuitanYLosDelMedioSeConservan() {
        assertEquals("ana maria", TextoBusqueda.normalizar("  Ana María "));
    }

    @Test
    void otrosSignosNoSeTocan() {
        assertEquals("o'brien-123", TextoBusqueda.normalizar("O'Brien-123"));
    }

    @Test
    void elPatronEsContieneYEscapaLosComodines() {
        assertEquals("%100!%!_a!!%", TextoBusqueda.patron("100%_a!"));
    }

    @Test
    void elPatronNormalizaElTexto() {
        assertEquals("%perez%", TextoBusqueda.patron(" Pérez "));
    }

    @Test
    void laColumnaSeNormalizaConElMismoMapaQueElTexto() {
        assertEquals(
                "LOWER(translate(p.apellido, 'áéíóúüÁÉÍÓÚÜÑ', 'aeiouuAEIOUUñ'))",
                TextoBusqueda.columna("p.apellido"));
    }

    @Test
    void laCondicionUsaLaColumnaNormalizadaYElEscape() {
        assertEquals(
                "LOWER(translate(nombre, 'áéíóúüÁÉÍÓÚÜÑ', 'aeiouuAEIOUUñ'))"
                        + " LIKE ? ESCAPE '!'",
                TextoBusqueda.contiene("nombre"));
    }
}
