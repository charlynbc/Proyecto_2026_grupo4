package uy.edu.proyecto.backend.pase;

import java.time.LocalDate;
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

import uy.edu.proyecto.backend.atencion.AtencionMedicaDTO;
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

@WebMvcTest(controllers = PaseMedicoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class PaseMedicoSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private PaseMedicoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void sinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/medico/pases"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void rolesDistintosDeMedicoReciben403() throws Exception {
        var socio = jwt().authorities(new SimpleGrantedAuthority("ROLE_SOCIO"));
        var funcionario = jwt().authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"));
        var admin = jwt().authorities(new SimpleGrantedAuthority("ROLE_ADMINISTRADOR"));

        mockMvc.perform(get("/api/medico/pases").with(socio))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/medico/pases").with(funcionario))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/medico/pases").with(admin))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void medicoListaSusPasesEmitidos() throws Exception {
        when(service.listar(17L, "DISPONIBLE", null, null))
                .thenReturn(List.of(new PaseEmitidoDTO(
                        78L,
                        new AtencionMedicaDTO.PacienteRef(7L, "20000012", "Sofia", "Socia"),
                        new Especialidad(4L, "Cardiologia", true),
                        OffsetDateTime.parse("2026-10-20T09:41:00-03:00"),
                        LocalDate.of(2027, 1, 18),
                        "DISPONIBLE")));
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(get("/api/medico/pases").with(medico)
                        .param("situacion", "DISPONIBLE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(78))
                .andExpect(jsonPath("$[0].paciente.apellido").value("Socia"))
                .andExpect(jsonPath("$[0].especialidadDestino.nombre").value("Cardiologia"))
                .andExpect(jsonPath("$[0].situacion").value("DISPONIBLE"));

        verify(service).listar(17L, "DISPONIBLE", null, null);
    }
}
