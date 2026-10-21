package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import org.junit.jupiter.api.Test;

class CiUruguayaTest {

    @Test
    void aceptaCiDeSieteDigitos() {
        assertEquals("1234561", CiUruguaya.normalizarValida("1234561").orElseThrow());
    }

    @Test
    void aceptaCiDeOchoDigitos() {
        assertEquals("67890127", CiUruguaya.normalizarValida("6.789.012-7").orElseThrow());
    }

    @Test
    void rechazaDigitoVerificadorIncorrecto() {
        assertFalse(CiUruguaya.normalizarValida("67890128").isPresent());
    }

    @Test
    void rechazaLongitudIncorrecta() {
        assertFalse(CiUruguaya.normalizarValida("123456").isPresent());
    }

    @Test
    void rechazaCaracteresQueNoSonSeparadores() {
        assertFalse(CiUruguaya.normalizarValida("67890A27").isPresent());
    }
}
