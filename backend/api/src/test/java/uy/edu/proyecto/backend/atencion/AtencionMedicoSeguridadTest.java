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

@WebMvcTest(controllers = AtencionMedicoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AtencionMedicoSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AtencionMedicoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private AtencionMedicaDTO atencion() {
        return new AtencionMedicaDTO(
                1L, LocalDate.of(2026, 10, 20),
                new AtencionMedicaDTO.PacienteRef(7L, "20000012", "Sofia", "Socia"),
                new Especialidad(9L, "Medicina General", false),
                "Afeccion", "Tratamiento", null, List.of());
    }

    @Test
    void sinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/medico/atenciones"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/medico/atenciones/1"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void rolesDistintosDeMedicoReciben403() throws Exception {
        var socio = jwt().authorities(new SimpleGrantedAuthority("ROLE_SOCIO"));
        var funcionario = jwt().authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"));

        mockMvc.perform(get("/api/medico/atenciones").with(socio)
                        .param("fechaDesde", "2026-10-01")
                        .param("fechaHasta", "2026-10-31"))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/medico/atenciones/1").with(funcionario))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void medicoListaSusAtenciones() throws Exception {
        when(service.listar(17L, "2026-10-01", "2026-10-31", null, null, null, null))
                .thenReturn(List.of(atencion()));
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(get("/api/medico/atenciones").with(medico)
                        .param("fechaDesde", "2026-10-01")
                        .param("fechaHasta", "2026-10-31"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].idAtencion").value(1))
                .andExpect(jsonPath("$[0].paciente.ci").value("20000012"))
                .andExpect(jsonPath("$[0].especialidad.nombre").value("Medicina General"));

        verify(service).listar(17L, "2026-10-01", "2026-10-31", null, null, null, null);
    }

    @Test
    void medicoVeElDetalleDeUnaAtencionPropia() throws Exception {
        when(service.detalle(17L, 1L)).thenReturn(atencion());
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(get("/api/medico/atenciones/1").with(medico))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.idAtencion").value(1))
                .andExpect(jsonPath("$.afeccion").value("Afeccion"));

        verify(service).detalle(17L, 1L);
    }

    @Test
    void identificadorDeAtencionNoNumericoDevuelve400() throws Exception {
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(get("/api/medico/atenciones/abc").with(medico))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verifyNoInteractions(service);
    }
}
