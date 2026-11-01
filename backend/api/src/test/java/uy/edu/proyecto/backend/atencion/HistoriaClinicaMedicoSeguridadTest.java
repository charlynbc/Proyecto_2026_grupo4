package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
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

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.especialidad.Especialidad;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = HistoriaClinicaMedicoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class HistoriaClinicaMedicoSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private HistoriaClinicaMedicoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void sinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/medico/pacientes/7/historia-clinica"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void rolesDistintosDeMedicoReciben403() throws Exception {
        var socio = jwt().authorities(new SimpleGrantedAuthority("ROLE_SOCIO"));
        var funcionario = jwt().authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"));
        var admin = jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMINISTRADOR"));

        mockMvc.perform(get("/api/medico/pacientes/7/historia-clinica").with(socio))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/medico/pacientes/7/historia-clinica").with(funcionario))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/medico/pacientes/7/historia-clinica").with(admin))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void medicoConsultaHistoriaDePacienteHabilitado() throws Exception {
        when(service.listar(17L, 7L)).thenReturn(List.of(new HistoriaClinicaDTO(
                1L, LocalDate.of(2026, 10, 1), 17L, "Mario", "Medina",
                new Especialidad(9L, "Medicina General", false),
                "Afeccion", "Tratamiento", null, List.of())));
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(get("/api/medico/pacientes/7/historia-clinica").with(medico))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].idAtencion").value(1))
                .andExpect(jsonPath("$[0].afeccion").value("Afeccion"));

        verify(service).listar(17L, 7L);
    }

    @Test
    void identificadorDePacienteNoNumericoDevuelve400() throws Exception {
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(get("/api/medico/pacientes/abc/historia-clinica").with(medico))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verifyNoInteractions(service);
    }
}
