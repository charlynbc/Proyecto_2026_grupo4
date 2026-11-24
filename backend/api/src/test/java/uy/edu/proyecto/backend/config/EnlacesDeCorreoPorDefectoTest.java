package uy.edu.proyecto.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;

import uy.edu.proyecto.backend.auth.PrimerIngresoMailListener;
import uy.edu.proyecto.backend.auth.RecuperacionMailListener;
import uy.edu.proyecto.backend.usuario.CambioCorreoMailListener;

/**
 * Los enlaces de los correos apuntan a rutas de la app web sin # (el servidor
 * responde el index.html en esas rutas). Los valores por defecto, los de
 * application.properties y los de cada listener, tienen que ir sin #.
 */
class EnlacesDeCorreoPorDefectoTest {

    private static Properties propiedades() throws IOException {
        Properties propiedades = new Properties();
        try (InputStream entrada = new ClassPathResource("application.properties").getInputStream()) {
            propiedades.load(entrada);
        }
        return propiedades;
    }

    /** El @Value del segundo parametro del constructor (el primero es el CorreoSender). */
    private static String valorPorDefecto(Class<?> listener) {
        return listener.getConstructors()[0].getParameters()[1].getAnnotation(Value.class).value();
    }

    @Test
    void applicationPropertiesTraeLosEnlacesSinNumeral() throws IOException {
        Properties propiedades = propiedades();

        assertEquals(
                "${FIRST_LOGIN_URL:http://localhost:5173/primer-ingreso}",
                propiedades.getProperty("app.email.first-login-url"));
        assertEquals(
                "${RECOVERY_URL:http://localhost:5173/recuperacion}",
                propiedades.getProperty("app.email.recovery-url"));
        assertEquals(
                "${CHANGE_EMAIL_URL:http://localhost:5173/cambio-correo}",
                propiedades.getProperty("app.email.change-email-url"));
    }

    @Test
    void elListenerDePrimerIngresoTieneUnDefectoSinNumeral() {
        assertEquals(
                "${app.email.first-login-url:http://localhost:5173/primer-ingreso}",
                valorPorDefecto(PrimerIngresoMailListener.class));
    }

    @Test
    void elListenerDeRecuperacionTieneUnDefectoSinNumeral() {
        assertEquals(
                "${app.email.recovery-url:http://localhost:5173/recuperacion}",
                valorPorDefecto(RecuperacionMailListener.class));
    }

    @Test
    void elListenerDeCambioDeCorreoTieneUnDefectoSinNumeral() {
        assertEquals(
                "${app.email.change-email-url:http://localhost:5173/cambio-correo}",
                valorPorDefecto(CambioCorreoMailListener.class));
    }
}
