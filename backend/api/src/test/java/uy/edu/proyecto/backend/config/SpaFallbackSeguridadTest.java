package uy.edu.proyecto.backend.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.forwardedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import uy.edu.proyecto.backend.usuario.AltaUsuarioController;
import uy.edu.proyecto.backend.usuario.AltaUsuarioService;
import uy.edu.proyecto.backend.usuario.UsuarioService;

/**
 * Las rutas de la app Flutter web (sin # en la URL) responden el index.html sin
 * sesion; todo lo demas sigue como antes. MockMvc no ejecuta el forward: aca se
 * comprueba a donde manda y la seguridad. El contenido servido de verdad lo
 * comprueba SpaFallbackServidorTest.
 */
@WebMvcTest(controllers = AltaUsuarioController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class SpaFallbackSeguridadTest {

    /** Cada ruta de la app, escrita a mano: la raiz de cada prefijo y una subruta real. */
    private static final List<String> RUTAS_DE_LA_APP = List.of(
            "/login",
            "/primer-ingreso",
            "/primer-ingreso/solicitar",
            "/recuperacion",
            "/recuperacion/solicitar",
            "/cambio-correo",
            "/cuenta",
            "/cuenta/editar",
            "/cuenta/contrasena",
            "/socio",
            "/socio/avisos",
            "/socio/historia/12",
            "/funcionario",
            "/funcionario/turnos/nuevo",
            "/medico",
            "/medico/atenciones/7",
            "/admin",
            "/admin/usuarios"
    );

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AltaUsuarioService service;

    @MockitoBean
    private UsuarioService usuarioService;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void cadaRutaDeLaAppSinSesionDevuelve200YSeReenviaAlIndex() throws Exception {
        for (String ruta : RUTAS_DE_LA_APP) {
            mockMvc.perform(get(ruta))
                    .andExpect(status().isOk())
                    .andExpect(forwardedUrl("/index.html"));
        }
    }

    @Test
    void laQueryStringLlegaConElTokenAlReenviar() throws Exception {
        MvcResult resultado = mockMvc.perform(get("/primer-ingreso?token=abc"))
                .andExpect(status().isOk())
                .andExpect(forwardedUrl("/index.html"))
                .andReturn();

        org.junit.jupiter.api.Assertions.assertEquals("abc", resultado.getRequest().getParameter("token"));
        org.junit.jupiter.api.Assertions.assertEquals("token=abc", resultado.getRequest().getQueryString());
    }

    @Test
    void laApiInexistenteSigueDando401Json() throws Exception {
        mockMvc.perform(get("/api/no-existe"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("NO_AUTENTICADO"));
    }

    @Test
    void unaRutaQueNoEsDeLaAppSigueDando401() throws Exception {
        mockMvc.perform(get("/ruta-no-estatica"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/socios"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/administrador"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void escribirEnUnaRutaDeLaAppPideSesion() throws Exception {
        mockMvc.perform(post("/primer-ingreso"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(post("/socio/avisos"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void losArchivosEstaticosRealesNoCambian() throws Exception {
        mockMvc.perform(get("/index.html"))
                .andExpect(status().isOk())
                .andExpect(content().string(Matchers.containsString("app-web-de-prueba")));
        mockMvc.perform(get("/assets/test.txt"))
                .andExpect(status().isOk())
                .andExpect(content().string(Matchers.containsString("asset-publico")));
    }
}
