package uy.edu.proyecto.backend.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.usuario.AltaUsuarioController;
import uy.edu.proyecto.backend.usuario.AltaUsuarioService;

/**
 * La app Flutter web se sirve desde el mismo origen que la API (DA-11): sus
 * archivos son públicos, pero la API sigue pidiendo sesión. El index.html de
 * prueba está en src/test/resources/static.
 */
@WebMvcTest(controllers = AltaUsuarioController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AppWebSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AltaUsuarioService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void archivosDeLaAppWebSonPublicos() throws Exception {
        mockMvc.perform(get("/index.html"))
                .andExpect(status().isOk())
                .andExpect(content().string(Matchers.containsString("app-web-de-prueba")));
        mockMvc.perform(get("/assets/test.txt"))
                .andExpect(status().isOk())
                .andExpect(content().string(Matchers.containsString("asset-publico")));
        mockMvc.perform(get("/canvaskit/test.js"))
                .andExpect(status().isOk())
                .andExpect(content().string(Matchers.containsString("canvaskit-publico")));
    }

    @Test
    void laRaizNoPideSesion() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk());
    }

    @Test
    void rutaDeApiInexistenteSigueProtegida() throws Exception {
        mockMvc.perform(get("/api/no-existe"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void rutasDesconocidasYErrorNoSonPublicos() throws Exception {
        mockMvc.perform(get("/ruta-no-estatica"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/error"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void escribirFueraDeLaApiPideSesion() throws Exception {
        mockMvc.perform(post("/index.html"))
                .andExpect(status().isUnauthorized());
    }
}
