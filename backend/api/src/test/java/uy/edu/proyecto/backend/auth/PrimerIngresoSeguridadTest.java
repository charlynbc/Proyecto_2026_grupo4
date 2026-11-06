package uy.edu.proyecto.backend.auth;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;

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

@WebMvcTest(controllers = PrimerIngresoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class PrimerIngresoSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private PrimerIngresoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void solicitarEnlaceEsPublico() throws Exception {
        when(service.solicitar(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new SolicitudPrimerIngresoResponse("mensaje"));

        mockMvc.perform(
                        post("/api/auth/primer-ingreso/solicitar")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"ci":"67890127","acceso":"SOCIO"}
                                        """)
                )
                .andExpect(status().isAccepted());
    }

    @Test
    void validarEnlaceEsPublicoYResponde200SinCuerpo() throws Exception {
        mockMvc.perform(post("/api/auth/primer-ingreso/validar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"token\"}"))
                .andExpect(status().isOk())
                .andExpect(content().string(""));

        verify(service).validarEnlace(new ValidarEnlaceRequest("token"));
    }

    @Test
    void completarEnlaceEsPublico() throws Exception {
        when(service.completar(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new CuentaActivadaResponse(
                        12L,
                        "67890127",
                        "Ana",
                        "Perez",
                        "SOCIO",
                        "ACTIVA",
                        true
                ));

        mockMvc.perform(
                        post("/api/auth/primer-ingreso/completar")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "token":"token",
                                          "direccion":"Direccion",
                                          "telefono1":"099111222",
                                          "password":"claveSegura1"
                                        }
                                        """)
                )
                .andExpect(status().isOk());
    }
}
