package uy.edu.proyecto.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.ImplFirebaseTrampolines;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

/** Sin llamar a Firebase real: solo se inicializa la FirebaseApp local, sin red. */
class FirebaseConfigTest {

    private static final String EMAIL = "config@proyecto-falso.iam.example.invalid";
    private static final String PROYECTO = "proyecto-config-falso";

    private final ApplicationContextRunner runner =
            new ApplicationContextRunner()
                    .withUserConfiguration(FirebaseConfig.class)
                    // Explicito para que el resultado no dependa del entorno de quien corre el test.
                    .withPropertyValues("app.firebase.enabled=true");

    @BeforeEach
    @AfterEach
    void limpiarFirebase() {
        FirebaseApp.getApps().forEach(FirebaseApp::delete);
    }

    private static String base64(String texto) {
        return Base64.getEncoder().encodeToString(texto.getBytes(StandardCharsets.UTF_8));
    }

    @Test
    void conVariableConJsonCreaLaAppConEsaCuenta() throws Exception {
        String json = FirebaseCredencialesTest.jsonCuenta(EMAIL, PROYECTO);

        runner.withPropertyValues("FIREBASE_SERVICE_ACCOUNT_JSON=" + json).run(contexto -> {
            assertNull(contexto.getStartupFailure());
            FirebaseApp app = contexto.getBean(FirebaseApp.class);
            assertEquals(PROYECTO, ImplFirebaseTrampolines.getProjectId(app));
        });
    }

    @Test
    void conVariableEnBase64CreaLaAppConEsaCuenta() throws Exception {
        String json = FirebaseCredencialesTest.jsonCuenta(EMAIL, PROYECTO);

        runner.withPropertyValues("FIREBASE_SERVICE_ACCOUNT_JSON=" + base64(json)).run(contexto -> {
            assertNull(contexto.getStartupFailure());
            FirebaseApp app = contexto.getBean(FirebaseApp.class);
            assertEquals(PROYECTO, ImplFirebaseTrampolines.getProjectId(app));
        });
    }

    @Test
    void conVariableInvalidaElArranqueFallaSinMostrarElValor() {
        runner.withPropertyValues("FIREBASE_SERVICE_ACCOUNT_JSON={no-es-json-SECRETO777")
                .run(contexto -> {
                    Throwable error = contexto.getStartupFailure();
                    assertNotNull(error);
                    boolean tieneNuestraExcepcion = false;
                    for (Throwable actual = error; actual != null; actual = actual.getCause()) {
                        assertFalse(String.valueOf(actual.getMessage()).contains("SECRETO777"));
                        if (actual instanceof FirebaseCredencialesInvalidasException) {
                            tieneNuestraExcepcion = true;
                        }
                    }
                    assertTrue(tieneNuestraExcepcion);
                });
    }

    @Test
    void conFirebaseApagadoNoSeCreaLaApp() throws Exception {
        String json = FirebaseCredencialesTest.jsonCuenta(EMAIL, PROYECTO);

        runner.withPropertyValues(
                "app.firebase.enabled=false",
                "FIREBASE_SERVICE_ACCOUNT_JSON=" + json
        ).run(contexto -> {
            assertNull(contexto.getStartupFailure());
            assertEquals(0, contexto.getBeansOfType(FirebaseApp.class).size());
            assertTrue(FirebaseApp.getApps().isEmpty());
        });
    }

    @Test
    void siYaHayUnaAppInicializadaSeReutilizaSinLeerLaVariable() throws Exception {
        String json = FirebaseCredencialesTest.jsonCuenta(EMAIL, PROYECTO);
        GoogleCredentials existentes = ServiceAccountCredentials.fromStream(
                new java.io.ByteArrayInputStream(json.getBytes(StandardCharsets.UTF_8)));
        FirebaseApp previa = FirebaseApp.initializeApp(
                FirebaseOptions.builder().setCredentials(existentes).build());

        runner.withPropertyValues("FIREBASE_SERVICE_ACCOUNT_JSON={invalida-no-se-lee")
                .run(contexto -> {
                    assertNull(contexto.getStartupFailure());
                    assertSame(previa, contexto.getBean(FirebaseApp.class));
                });
    }
}
