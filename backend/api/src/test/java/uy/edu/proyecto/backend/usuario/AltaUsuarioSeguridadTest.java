package uy.edu.proyecto.backend.usuario;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

@WebMvcTest(controllers = AltaUsuarioController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AltaUsuarioSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AltaUsuarioService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void solicitudSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(
                        post("/api/usuarios")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{}")
                )
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioNoPuedeCrearUsuarios() throws Exception {
        mockMvc.perform(
                        post("/api/usuarios")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{}")
                )
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorPuedeCrearUsuarios() throws Exception {
        when(service.crear(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new CuentaCreadaResponse(
                        12L,
                        "67890127",
                        "Ana",
                        "Perez",
                        "SOCIO",
                        "ACTIVA",
                        false
                ));

        mockMvc.perform(
                        post("/api/usuarios")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "ci":"67890127",
                                          "nombre":"Ana",
                                          "apellido":"Perez",
                                          "fechaNacimiento":"1990-01-01",
                                          "correo":"ana@example.org",
                                          "telefono1":"099111222",
                                          "rol":"SOCIO"
                                        }
                                        """)
                )
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.activada").value(false));
    }
}
