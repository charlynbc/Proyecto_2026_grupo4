package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.Test;

class GuardaBaseE2ETest {

    @ParameterizedTest
    @ValueSource(strings = {
            "jdbc:postgresql://localhost:55432/proyecto_e2e",
            "jdbc:postgresql://127.0.0.1/proyecto_test",
            "jdbc:postgresql://localhost:5432/a1_e2e"})
    void admiteNombresDePruebaLocales(String url) {
        String nombre = GuardaBaseE2E.validar(url, "true");
        assertEquals(url.substring(url.lastIndexOf('/') + 1), nombre);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "jdbc:postgresql://localhost:5432/Proyecto_e2e",
            "jdbc:postgresql://localhost:5432/123_e2e",
            "jdbc:postgresql://localhost:5432/_e2e",
            "jdbc:postgresql://localhost:5432/proyecto",
            "jdbc:postgresql://localhost:5432/postgres",
            "jdbc:postgresql://localhost:5432/proyecto_e2e;DROP DATABASE x",
            "jdbc:postgresql://localhost:5432/proyecto-e2e",
            "jdbc:postgresql://localhost:5432/proyecto_e2e?sslmode=disable",
            "jdbc:postgresql://db.supabase.co:5432/proyecto_e2e",
            "jdbc:postgresql://localhost.evil.com:5432/proyecto_e2e",
            "jdbc:postgresql://10.0.0.5:5432/proyecto_e2e",
            "jdbc:mysql://localhost:3306/proyecto_e2e",
            ""})
    void rechazaNombresYHostsNoAutorizados(String url) {
        assertThrows(IllegalStateException.class, () -> GuardaBaseE2E.validar(url, "true"));
    }

    @Test
    void rechazaUrlNula() {
        assertThrows(IllegalStateException.class, () -> GuardaBaseE2E.validar(null, "true"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "false", "TRUE", "1", "yes"})
    void exigeHabilitacionExplicita(String valor) {
        assertThrows(IllegalStateException.class,
                () -> GuardaBaseE2E.validar("jdbc:postgresql://localhost:5432/proyecto_e2e", valor));
    }

    @Test
    void rechazaSinHabilitacion() {
        assertThrows(IllegalStateException.class,
                () -> GuardaBaseE2E.validar("jdbc:postgresql://localhost:5432/proyecto_e2e", null));
    }

    @Test
    void entrecomillaIdentificadores() {
        assertEquals("\"proyecto_e2e\"", GuardaBaseE2E.identificador("proyecto_e2e"));
        assertEquals("\"a\"\"b\"", GuardaBaseE2E.identificador("a\"b"));
    }
}
