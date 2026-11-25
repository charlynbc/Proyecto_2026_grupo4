package uy.edu.proyecto.backend.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * /.well-known/assetlinks.json es publico solo por GET y solo esa ruta. Se
 * prueba con las propiedades por defecto de application.properties: el cuerpo
 * esperado, escrito a mano, lleva el paquete real y la huella de la clave debug.
 */
@WebMvcTest(controllers = AssetLinksController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AssetLinksSeguridadTest {

    private static final String CUERPO_POR_DEFECTO =
            "[{\"relation\":[\"delegate_permission/common.handle_all_urls\"],"
                    + "\"target\":{\"namespace\":\"android_app\","
                    + "\"package_name\":\"uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica\","
                    + "\"sha256_cert_fingerprints\":["
                    + "\"01:AC:05:8D:AC:C7:69:7C:34:98:6D:2D:8A:68:D6:D7:51:F7:F4:B3:0C:69:CB:11:0C:0C:88:8D:23:20:4F:0C\""
                    + "]}}]";

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void sinSesionResponde200ConElJsonPorDefecto() throws Exception {
        mockMvc.perform(get("/.well-known/assetlinks.json"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(content().string(CUERPO_POR_DEFECTO));
    }

    @Test
    void unPostNoEsPublico() throws Exception {
        mockMvc.perform(post("/.well-known/assetlinks.json"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void otrosMetodosNoSonPublicos() throws Exception {
        mockMvc.perform(put("/.well-known/assetlinks.json"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(delete("/.well-known/assetlinks.json"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void otraRutaBajoWellKnownSigueDando401() throws Exception {
        mockMvc.perform(get("/.well-known/otra-cosa"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/.well-known/assetlinks.json/otra"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/.well-known/"))
                .andExpect(status().isUnauthorized());
    }
}
