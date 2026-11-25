package uy.edu.proyecto.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

/**
 * /.well-known/assetlinks.json por HTTP real (puerto aleatorio) y sin
 * PostgreSQL, con la misma configuracion aislada que SpaFallbackServidorTest.
 * Android pide el archivo sin seguir redirecciones: aca tampoco se siguen.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@TestPropertySource(properties = {
        "app.firebase.enabled=false",
        "spring.datasource.url=jdbc:postgresql://127.0.0.1:1/aislada",
        "spring.datasource.username=test",
        "spring.datasource.password=test",
        "app.jwt.secret-base64=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
        "app.mail.provider=none",
        "app.notificaciones.procesos-programados.habilitados=false",
        "app.android.package-name=uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica",
        "app.android.sha256-fingerprints=01:AC:05:8D:AC:C7:69:7C:34:98:6D:2D:8A:68:D6:D7:51:F7:F4:B3:0C:69:CB:11:0C:0C:88:8D:23:20:4F:0C"
})
class AssetLinksServidorTest {

    @Value("${local.server.port}")
    private int puerto;

    private final HttpClient http = HttpClient.newBuilder()
            .followRedirects(HttpClient.Redirect.NEVER)
            .build();

    private HttpResponse<String> get(String ruta) throws Exception {
        return http.send(
                HttpRequest.newBuilder(URI.create("http://localhost:" + puerto + ruta)).GET().build(),
                HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void sirveElJsonExactoSinRedireccionYSinSesion() throws Exception {
        HttpResponse<String> respuesta = get("/.well-known/assetlinks.json");

        assertEquals(200, respuesta.statusCode());
        assertTrue(
                respuesta.headers().firstValue("Content-Type").orElse("").startsWith("application/json"),
                respuesta.headers().toString());
        assertEquals(
                "[{\"relation\":[\"delegate_permission/common.handle_all_urls\"],"
                        + "\"target\":{\"namespace\":\"android_app\","
                        + "\"package_name\":\"uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica\","
                        + "\"sha256_cert_fingerprints\":["
                        + "\"01:AC:05:8D:AC:C7:69:7C:34:98:6D:2D:8A:68:D6:D7:51:F7:F4:B3:0C:69:CB:11:0C:0C:88:8D:23:20:4F:0C\""
                        + "]}}]",
                respuesta.body());
    }

    @Test
    void otraRutaBajoWellKnownDa401() throws Exception {
        assertEquals(401, get("/.well-known/otra-cosa").statusCode());
    }
}
