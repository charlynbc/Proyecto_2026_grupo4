package uy.edu.proyecto.backend.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpHeaders;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import uy.edu.proyecto.backend.anuncio.CarteleraController;
import uy.edu.proyecto.backend.anuncio.CarteleraService;

/**
 * El navegador pregunta con un OPTIONS (preflight) si puede mandar el metodo
 * real. Si el metodo no esta permitido, cancela la peticion antes de enviarla.
 */
@WebMvcTest(controllers = CarteleraController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class CorsPreflightTest {

    private static final String ORIGEN = "http://localhost:5173";
    private static final String RUTA = "/api/admin/anuncios/1/vigencia";

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private CarteleraService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private ResultActions preflight(String origen, String metodo) throws Exception {
        return mockMvc.perform(options(RUTA)
                .header(HttpHeaders.ORIGIN, origen)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, metodo)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "authorization,content-type"));
    }

    @Test
    void preflightDePutDesdeElOrigenPermitidoEsAceptado() throws Exception {
        preflight(ORIGEN, "PUT")
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, ORIGEN))
                .andExpect(header().string(
                        HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, Matchers.containsString("PUT")));
    }

    @Test
    void preflightDeDeleteSigueAceptado() throws Exception {
        preflight(ORIGEN, "DELETE")
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, ORIGEN))
                .andExpect(header().string(
                        HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, Matchers.containsString("DELETE")));
    }

    @Test
    void preflightDePatchSigueAceptado() throws Exception {
        preflight(ORIGEN, "PATCH")
                .andExpect(status().isOk())
                .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, ORIGEN))
                .andExpect(header().string(
                        HttpHeaders.ACCESS_CONTROL_ALLOW_METHODS, Matchers.containsString("PATCH")));
    }

    @Test
    void preflightDesdeUnOrigenNoPermitidoNoDevuelveAllowOrigin() throws Exception {
        preflight("http://otro.example.com", "PUT")
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }
}
