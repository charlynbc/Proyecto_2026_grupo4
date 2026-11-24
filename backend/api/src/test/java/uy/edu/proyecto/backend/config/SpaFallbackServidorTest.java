package uy.edu.proyecto.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import jakarta.servlet.DispatcherType;
import jakarta.servlet.Filter;
import jakarta.servlet.http.HttpServletRequest;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.TestPropertySource;

/**
 * El fallback de la app web contra un servidor real (puerto aleatorio) y sin
 * PostgreSQL: arranca con la misma configuracion aislada que ArranqueAisladoTest.
 * Sirve el src/test/resources/static/index.html de prueba. MockMvc no ejecuta el
 * forward; aca si, y un filtro de prueba anota lo que llega al index.html
 * reenviado, para comprobar que el token de la URL no se pierde.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Import(SpaFallbackServidorTest.RegistroDeReenvios.class)
@TestPropertySource(properties = {
        "app.firebase.enabled=false",
        "spring.datasource.url=jdbc:postgresql://127.0.0.1:1/aislada",
        "spring.datasource.username=test",
        "spring.datasource.password=test",
        "app.jwt.secret-base64=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
        "app.mail.provider=none",
        "app.notificaciones.procesos-programados.habilitados=false"
})
class SpaFallbackServidorTest {

    /** Lo que vio el servlet en cada reenvio: la URI de destino y el token. */
    record Reenvio(String uri, String token, String queryOriginal) {
    }

    @TestConfiguration
    static class RegistroDeReenvios {
        static final List<Reenvio> REENVIOS = new CopyOnWriteArrayList<>();

        @Bean
        FilterRegistrationBean<Filter> registroDeReenvios() {
            FilterRegistrationBean<Filter> registro = new FilterRegistrationBean<>((request, response, chain) -> {
                HttpServletRequest http = (HttpServletRequest) request;
                REENVIOS.add(new Reenvio(
                        http.getRequestURI(),
                        http.getParameter("token"),
                        (String) http.getAttribute("jakarta.servlet.forward.query_string")));
                chain.doFilter(request, response);
            });
            registro.setDispatcherTypes(DispatcherType.FORWARD);
            registro.addUrlPatterns("/*");
            return registro;
        }
    }

    @Value("${local.server.port}")
    private int puerto;

    private final HttpClient http = HttpClient.newBuilder()
            .followRedirects(HttpClient.Redirect.NEVER)
            .build();

    @BeforeEach
    void limpiar() {
        RegistroDeReenvios.REENVIOS.clear();
    }

    private HttpResponse<String> get(String rutaYQuery) throws IOException, InterruptedException {
        return http.send(
                HttpRequest.newBuilder(URI.create("http://localhost:" + puerto + rutaYQuery)).GET().build(),
                HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void unaRutaDeLaAppSinSesionSirveElIndexHtml() throws Exception {
        HttpResponse<String> respuesta = get("/primer-ingreso?token=abc");

        assertEquals(200, respuesta.statusCode());
        assertTrue(respuesta.body().contains("app-web-de-prueba"), respuesta.body());
    }

    @Test
    void elReenvioConservaElTokenDeLaUrl() throws Exception {
        get("/primer-ingreso?token=abc");

        assertEquals(
                List.of(new Reenvio("/index.html", "abc", "token=abc")),
                RegistroDeReenvios.REENVIOS);
    }

    @Test
    void otrasRutasDeLaAppTambienSirvenElIndexHtml() throws Exception {
        for (String ruta : List.of("/recuperacion?token=xyz", "/cambio-correo?token=xyz", "/login",
                "/socio/historia/12", "/admin/usuarios")) {
            HttpResponse<String> respuesta = get(ruta);

            assertEquals(200, respuesta.statusCode(), ruta);
            assertTrue(respuesta.body().contains("app-web-de-prueba"), ruta);
        }
    }

    @Test
    void unArchivoEstaticoRealSeSirveComoAntes() throws Exception {
        HttpResponse<String> respuesta = get("/assets/test.txt");

        assertEquals(200, respuesta.statusCode());
        assertTrue(respuesta.body().contains("asset-publico"), respuesta.body());
        assertTrue(RegistroDeReenvios.REENVIOS.isEmpty());
    }

    @Test
    void lasRutasDeLaApiNoSeReenvian() throws Exception {
        HttpResponse<String> respuesta = get("/api/no-existe");

        assertEquals(401, respuesta.statusCode());
        assertTrue(respuesta.body().contains("NO_AUTENTICADO"), respuesta.body());
        assertTrue(RegistroDeReenvios.REENVIOS.isEmpty());
    }

    @Test
    void unaRutaQueNoEsDeLaAppSigueDando401() throws Exception {
        HttpResponse<String> respuesta = get("/ruta-no-estatica");

        assertEquals(401, respuesta.statusCode());
        assertTrue(RegistroDeReenvios.REENVIOS.isEmpty());
    }
}
