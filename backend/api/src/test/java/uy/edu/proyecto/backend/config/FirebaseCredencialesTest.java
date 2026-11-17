package uy.edu.proyecto.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicInteger;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;

import org.junit.jupiter.api.Test;

/** Las claves de prueba se generan al correr el test; no hay ninguna guardada en el repo. */
class FirebaseCredencialesTest {

    private static final String EMAIL = "prueba@proyecto-falso.iam.example.invalid";
    private static final String PROYECTO = "proyecto-falso-123";

    /** JSON de cuenta de servicio con una clave RSA recien generada y datos de mentira. */
    static String jsonCuenta(String email, String proyecto) throws Exception {
        KeyPairGenerator generador = KeyPairGenerator.getInstance("RSA");
        generador.initialize(2048);
        KeyPair par = generador.generateKeyPair();
        String cuerpo = Base64.getEncoder().encodeToString(par.getPrivate().getEncoded());
        String pem = "-----BEGIN PRIVATE KEY-----\\n" + cuerpo + "\\n-----END PRIVATE KEY-----\\n";
        return "{\"type\":\"service_account\","
                + "\"project_id\":\"" + proyecto + "\","
                + "\"private_key_id\":\"id-de-mentira\","
                + "\"private_key\":\"" + pem + "\","
                + "\"client_email\":\"" + email + "\","
                + "\"client_id\":\"123456789\","
                + "\"token_uri\":\"https://oauth2.example.invalid/token\"}";
    }

    private static String base64(String texto) {
        return Base64.getEncoder().encodeToString(texto.getBytes(StandardCharsets.UTF_8));
    }

    private static GoogleCredentials sinUsar() {
        throw new AssertionError("No debia usar el camino por defecto");
    }

    private static ServiceAccountCredentials cuenta(GoogleCredentials credenciales) {
        return (ServiceAccountCredentials) credenciales;
    }

    @Test
    void jsonPlanoDaLasCredencialesDeLaCuenta() throws Exception {
        GoogleCredentials credenciales =
                FirebaseCredenciales.desde(jsonCuenta(EMAIL, PROYECTO), FirebaseCredencialesTest::sinUsar);

        assertEquals(EMAIL, cuenta(credenciales).getClientEmail());
        assertEquals(PROYECTO, cuenta(credenciales).getProjectId());
    }

    @Test
    void base64DelMismoJsonDaLasMismasCredenciales() throws Exception {
        String json = jsonCuenta(EMAIL, PROYECTO);

        ServiceAccountCredentials plano =
                cuenta(FirebaseCredenciales.desde(json, FirebaseCredencialesTest::sinUsar));
        ServiceAccountCredentials codificado =
                cuenta(FirebaseCredenciales.desde(base64(json), FirebaseCredencialesTest::sinUsar));

        assertEquals(plano.getClientEmail(), codificado.getClientEmail());
        assertEquals(plano.getProjectId(), codificado.getProjectId());
        assertEquals(EMAIL, codificado.getClientEmail());
    }

    @Test
    void espaciosYSaltosDeLineaAlrededorSeIgnoran() throws Exception {
        String json = jsonCuenta(EMAIL, PROYECTO);

        ServiceAccountCredentials plano = cuenta(FirebaseCredenciales.desde(
                "  \r\n" + json + "\n  ", FirebaseCredencialesTest::sinUsar));
        ServiceAccountCredentials codificado = cuenta(FirebaseCredenciales.desde(
                "\n " + base64(json) + " \r\n", FirebaseCredencialesTest::sinUsar));

        assertEquals(EMAIL, plano.getClientEmail());
        assertEquals(EMAIL, codificado.getClientEmail());
    }

    @Test
    void base64PartidoEnLineasSeAcepta() throws Exception {
        String json = jsonCuenta(EMAIL, PROYECTO);
        String partido = base64(json).replaceAll("(.{76})", "$1\n");

        ServiceAccountCredentials credenciales =
                cuenta(FirebaseCredenciales.desde(partido, FirebaseCredencialesTest::sinUsar));

        assertEquals(PROYECTO, credenciales.getProjectId());
    }

    @Test
    void jsonInvalidoFallaConMensajeClaroSinElValor() {
        String valor = "{esto-no-es-json-SECRETO123";

        FirebaseCredencialesInvalidasException error = assertThrows(
                FirebaseCredencialesInvalidasException.class,
                () -> FirebaseCredenciales.desde(valor, FirebaseCredencialesTest::sinUsar));

        assertTrue(error.getMessage().contains("FIREBASE_SERVICE_ACCOUNT_JSON"));
        assertFalse(error.getMessage().contains("SECRETO123"));
        assertFalse(error.getMessage().contains("esto-no-es-json"));
        assertNull(error.getCause());
    }

    @Test
    void jsonSinLosCamposDeCuentaFallaSinElValor() {
        String valor = "{\"type\":\"service_account\",\"private_key\":\"SECRETO-ABC-789\"}";

        FirebaseCredencialesInvalidasException error = assertThrows(
                FirebaseCredencialesInvalidasException.class,
                () -> FirebaseCredenciales.desde(valor, FirebaseCredencialesTest::sinUsar));

        assertFalse(error.getMessage().contains("SECRETO-ABC-789"));
        assertNull(error.getCause());
    }

    @Test
    void base64InvalidoFallaConMensajeClaroSinElValor() {
        String valor = "!!!clave-invalida-ZZZ999!!!";

        FirebaseCredencialesInvalidasException error = assertThrows(
                FirebaseCredencialesInvalidasException.class,
                () -> FirebaseCredenciales.desde(valor, FirebaseCredencialesTest::sinUsar));

        assertTrue(error.getMessage().contains("FIREBASE_SERVICE_ACCOUNT_JSON"));
        assertFalse(error.getMessage().contains("ZZZ999"));
        assertFalse(error.getMessage().contains("clave-invalida"));
        assertNull(error.getCause());
    }

    @Test
    void base64QueNoContieneUnaCuentaFallaSinElValor() {
        String valor = base64("texto-que-no-es-una-cuenta-QQQ555");

        FirebaseCredencialesInvalidasException error = assertThrows(
                FirebaseCredencialesInvalidasException.class,
                () -> FirebaseCredenciales.desde(valor, FirebaseCredencialesTest::sinUsar));

        assertFalse(error.getMessage().contains(valor));
        assertFalse(error.getMessage().contains("QQQ555"));
        assertNull(error.getCause());
    }

    @Test
    void variableAusenteOVaciaUsaElCaminoPorDefecto() throws Exception {
        GoogleCredentials porDefecto = ServiceAccountCredentials.fromStream(
                new ByteArrayInputStream(
                        jsonCuenta("defecto@proyecto-falso.example.invalid", "otro-proyecto")
                                .getBytes(StandardCharsets.UTF_8)));
        AtomicInteger llamadas = new AtomicInteger();
        FirebaseCredenciales.CredencialesPorDefecto proveedor = () -> {
            llamadas.incrementAndGet();
            return porDefecto;
        };

        assertSame(porDefecto, FirebaseCredenciales.desde(null, proveedor));
        assertSame(porDefecto, FirebaseCredenciales.desde("", proveedor));
        assertSame(porDefecto, FirebaseCredenciales.desde("   \n ", proveedor));
        assertEquals(3, llamadas.get());
    }

    @Test
    void conVariableValidaNoSeConsultaElCaminoPorDefecto() throws Exception {
        AtomicInteger llamadas = new AtomicInteger();
        FirebaseCredenciales.CredencialesPorDefecto proveedor = () -> {
            llamadas.incrementAndGet();
            throw new IOException("no deberia llamarse");
        };

        FirebaseCredenciales.desde(jsonCuenta(EMAIL, PROYECTO), proveedor);

        assertEquals(0, llamadas.get());
    }
}
