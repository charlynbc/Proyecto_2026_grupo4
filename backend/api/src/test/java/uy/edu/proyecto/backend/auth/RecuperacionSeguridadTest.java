package uy.edu.proyecto.backend.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
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

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

@WebMvcTest(controllers = RecuperacionController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class RecuperacionSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private RecuperacionService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void solicitarEsPublicoYResponde202() throws Exception {
        when(service.solicitar(any())).thenReturn(
                new SolicitudPrimerIngresoResponse("mensaje"));

        mockMvc.perform(post("/api/auth/recuperacion/solicitar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"ci":"45678911","acceso":"SOCIO"}
                                """))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.message").value("mensaje"));

        verify(service).solicitar(any());
    }

    @Test
    void validarEnlaceEsPublicoYResponde200SinCuerpo() throws Exception {
        mockMvc.perform(post("/api/auth/recuperacion/validar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"token\"}"))
                .andExpect(status().isOk())
                .andExpect(content().string(""));

        verify(service).validarEnlace(new ValidarEnlaceRequest("token"));
    }

    @Test
    void completarEsPublicoYResponde200() throws Exception {
        mockMvc.perform(post("/api/auth/recuperacion/completar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"token":"abc","password":"Clave-Nueva-1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").exists());

        verify(service).completar(any());
    }
}
