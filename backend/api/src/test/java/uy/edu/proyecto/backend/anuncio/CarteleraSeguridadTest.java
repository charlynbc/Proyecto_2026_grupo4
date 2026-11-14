package uy.edu.proyecto.backend.anuncio;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers=CarteleraController.class)
@Import({SecurityConfig.class,SecurityErrorHandler.class})
@TestPropertySource(properties="app.cors.allowed-origin=http://localhost:5173")
class CarteleraSeguridadTest {
    @Autowired MockMvc mvc;
    @MockitoBean CarteleraService service;
    @MockitoBean JwtDecoder jwtDecoder;
    @Test void administracionSoloParaAdministrador() throws Exception {
        mvc.perform(get("/api/admin/anuncios")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/admin/anuncios").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SOCIO")))).andExpect(status().isForbidden());
        mvc.perform(delete("/api/admin/anuncios/1").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_MEDICO")))).andExpect(status().isForbidden());
        mvc.perform(get("/api/admin/anuncios").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMINISTRADOR")))).andExpect(status().isOk());
    }
}
