package uy.edu.proyecto.backend.usuario;

import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

import java.time.OffsetDateTime;
import java.util.List;

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
    private UsuarioService usuarioService;

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
    void listadoSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/usuarios"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioNoPuedeConsultarElPadron() throws Exception {
        mockMvc.perform(get("/api/usuarios"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(usuarioService);
    }

    @Test
    @WithMockUser(roles = "FUNCIONARIO")
    void funcionarioNoPuedeConsultarElPadron() throws Exception {
        mockMvc.perform(get("/api/usuarios"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(usuarioService);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorPuedeConsultarElPadronConFiltrosYSinCamposSecretos() throws Exception {
        when(usuarioService.listar("SOCIO", "INACTIVA", "45678911", 0, 20))
                .thenReturn(new UsuarioCuentaPageResponse(
                        List.of(new UsuarioCuentaDTO(
                                42L,
                                "45678911",
                                "Lucia",
                                "Fernandez",
                                "SOCIO",
                                "lucia@example.org",
                                "INACTIVA",
                                false,
                                OffsetDateTime.parse("2026-09-01T09:00:00-03:00")
                        )),
                        0,
                        20,
                        1
                ));

        mockMvc.perform(get("/api/usuarios")
                        .param("rol", "SOCIO")
                        .param("estado", "INACTIVA")
                        .param("texto", "45678911"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].ci").value("45678911"))
                .andExpect(jsonPath("$.items[0].rol").value("SOCIO"))
                .andExpect(jsonPath("$.items[0].estado").value("INACTIVA"))
                .andExpect(jsonPath("$.items[0].activada").value(false))
                .andExpect(jsonPath("$.items[0].password").doesNotExist())
                .andExpect(jsonPath("$.items[0].token").doesNotExist());

        verify(usuarioService).listar("SOCIO", "INACTIVA", "45678911", 0, 20);
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
