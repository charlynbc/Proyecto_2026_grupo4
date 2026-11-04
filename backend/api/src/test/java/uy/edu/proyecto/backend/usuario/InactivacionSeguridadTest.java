package uy.edu.proyecto.backend.usuario;

import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.JwtRequestPostProcessor;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

/**
 * Seguridad de la inactivacion y reactivacion de empleados (RF-45): ambos
 * endpoints son exclusivos del rol ADMINISTRADOR.
 */
@WebMvcTest(controllers = InactivacionEmpleadoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class InactivacionSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private InactivacionEmpleadoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private static JwtRequestPostProcessor conRol(String rol) {
        return jwt().jwt(token -> token.subject("1"))
                .authorities(new SimpleGrantedAuthority("ROLE_" + rol));
    }

    @Test
    void inactivarSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(post("/api/usuarios/10/inactivar"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void reactivarSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(post("/api/usuarios/10/reactivar"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void socioNoPuedeInactivarNiReactivar() throws Exception {
        mockMvc.perform(post("/api/usuarios/10/inactivar").with(conRol("SOCIO")))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/usuarios/10/reactivar").with(conRol("SOCIO")))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void funcionarioNoPuedeInactivarNiReactivar() throws Exception {
        mockMvc.perform(post("/api/usuarios/10/inactivar").with(conRol("FUNCIONARIO")))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/usuarios/10/reactivar").with(conRol("FUNCIONARIO")))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void medicoNoPuedeInactivarNiReactivar() throws Exception {
        mockMvc.perform(post("/api/usuarios/10/inactivar").with(conRol("MEDICO")))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/usuarios/10/reactivar").with(conRol("MEDICO")))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void administradorInactivaYReactiva() throws Exception {
        when(service.inactivar(anyLong(), anyLong()))
                .thenReturn(new EstadoCuentaResponse(
                        10L, "12345672", "Fabio", "Funcionario", "FUNCIONARIO",
                        "INACTIVA", null, 1L, null, null));
        when(service.reactivar(anyLong(), anyLong()))
                .thenReturn(new EstadoCuentaResponse(
                        10L, "12345672", "Fabio", "Funcionario", "FUNCIONARIO",
                        "ACTIVA", null, null, null, 1L));

        mockMvc.perform(post("/api/usuarios/10/inactivar")
                        .with(conRol("ADMINISTRADOR")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("INACTIVA"));
        mockMvc.perform(post("/api/usuarios/10/reactivar")
                        .with(conRol("ADMINISTRADOR")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("ACTIVA"));

        verify(service).inactivar(10L, 1L);
        verify(service).reactivar(10L, 1L);
    }
}

