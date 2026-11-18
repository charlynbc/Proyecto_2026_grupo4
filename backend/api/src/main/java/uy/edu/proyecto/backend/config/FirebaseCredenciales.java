package uy.edu.proyecto.backend.config;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;

/**
 * Arma las credenciales de Firebase a partir de FIREBASE_SERVICE_ACCOUNT_JSON.
 *
 * <p>El valor de la variable es secreto: nunca se copia a un mensaje de error ni a un
 * registro, y las excepciones de la libreria no se encadenan porque pueden citar
 * fragmentos de la entrada.
 */
public final class FirebaseCredenciales {

    static final String MENSAJE_INVALIDA =
            "No se pudo leer FIREBASE_SERVICE_ACCOUNT_JSON. Debe contener el JSON de la "
                    + "clave de la cuenta de servicio de Firebase o ese mismo JSON codificado "
                    + "en base64. Revise el valor cargado en la variable y vuelva a intentar.";

    /** Camino de respaldo: GOOGLE_APPLICATION_CREDENTIALS. */
    @FunctionalInterface
    public interface CredencialesPorDefecto {
        GoogleCredentials obtener() throws IOException;
    }

    private FirebaseCredenciales() {
    }

    /**
     * Usa el valor de la variable si no esta vacio; si lo esta, el camino por defecto.
     * Si empieza con una llave es el JSON; si no, se decodifica de base64.
     */
    public static GoogleCredentials desde(
            String valorVariable,
            CredencialesPorDefecto porDefecto
    ) throws IOException {
        String valor = valorVariable == null ? "" : valorVariable.strip();
        if (valor.isEmpty()) {
            return porDefecto.obtener();
        }
        byte[] json = valor.startsWith("{")
                ? valor.getBytes(StandardCharsets.UTF_8)
                : decodificar(valor);
        return leer(json);
    }

    private static byte[] decodificar(String valor) {
        try {
            return Base64.getDecoder().decode(valor.replaceAll("\\s", ""));
        } catch (IllegalArgumentException e) {
            throw invalidas();
        }
    }

    private static GoogleCredentials leer(byte[] json) {
        try {
            GoogleCredentials credenciales =
                    GoogleCredentials.fromStream(new ByteArrayInputStream(json));
            if (credenciales instanceof ServiceAccountCredentials) {
                return credenciales;
            }
        } catch (IOException | RuntimeException e) {
            // Se descarta a proposito: el mensaje de la libreria puede citar la entrada.
        }
        throw invalidas();
    }

    private static FirebaseCredencialesInvalidasException invalidas() {
        return new FirebaseCredencialesInvalidasException(MENSAJE_INVALIDA);
    }
}
