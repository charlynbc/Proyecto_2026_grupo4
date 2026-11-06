package uy.edu.proyecto.backend.anuncio;

import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.mock.web.MockMultipartFile;
import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AnuncioController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AnuncioSeguridadTest {
    @Autowired private MockMvc mockMvc;
    @MockitoBean private AnuncioService service;
    @MockitoBean private JwtDecoder jwtDecoder;

    @Test
    void carteleraRequiereSesionYLaPuedeLeerUnSocio() throws Exception {
        mockMvc.perform(get("/api/anuncios")).andExpect(status().isUnauthorized());
        verifyNoInteractions(service);

        when(service.listar(0, 5)).thenReturn(new AnuncioDTO.Pagina(List.of(), 0, 5, 0));
        mockMvc.perform(get("/api/anuncios?size=5")
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.size").value(5));
    }

    @Test
    void soloAdministradorPuedePublicar() throws Exception {
        mockMvc.perform(multipart("/api/anuncios").file(datos()).file(imagen()))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(multipart("/api/anuncios").file(datos()).file(imagen())
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);

        var publicado = new AnuncioDTO.Detalle(42, "Vacunación", null, "Texto",
                OffsetDateTime.parse("2026-11-03T12:00:00Z"),
                List.of(new AnuncioDTO.Imagen(1, 0, "https://example.test/imagen")));
        when(service.publicar(eq(7L), any(), any())).thenReturn(publicado);

        mockMvc.perform(multipart("/api/anuncios").file(datos()).file(imagen())
                        .with(jwt().jwt(token -> token.subject("7"))
                                .authorities(new SimpleGrantedAuthority("ROLE_ADMINISTRADOR"))))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/api/anuncios/42"))
                .andExpect(jsonPath("$.titulo").value("Vacunación"))
                .andExpect(jsonPath("$.imagenes[0].orden").value(0));
    }

    private static MockMultipartFile datos() {
        return new MockMultipartFile("datos", "", "application/json",
                "{\"titulo\":\"Vacunación\",\"texto\":\"Texto\"}"
                        .getBytes(StandardCharsets.UTF_8));
    }

    private static MockMultipartFile imagen() {
        return new MockMultipartFile("imagenes", "imagen.png", "image/png", new byte[]{1});
    }
}
