package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = CancelacionMedicoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class CancelacionMedicoSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private CancelacionMedicoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private static final String CUERPO = "{\"motivo\":\"Imprevisto\"}";

    @Test
    void sinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(post("/api/medico/consultas/12/cancelar")
                        .contentType(MediaType.APPLICATION_JSON).content(CUERPO))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(post("/api/medico/turnos/30/cancelar")
                        .contentType(MediaType.APPLICATION_JSON).content(CUERPO))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void rolesDistintosDeMedicoReciben403() throws Exception {
        var socio = jwt().authorities(new SimpleGrantedAuthority("ROLE_SOCIO"));
        var funcionario = jwt().authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"));

        mockMvc.perform(post("/api/medico/consultas/12/cancelar").with(socio)
                        .contentType(MediaType.APPLICATION_JSON).content(CUERPO))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/medico/turnos/30/cancelar").with(funcionario)
                        .contentType(MediaType.APPLICATION_JSON).content(CUERPO))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void medicoCancelaConsultaPropia() throws Exception {
        when(service.cancelarConsulta(eq(17L), eq("12"), eq("Imprevisto")))
                .thenReturn(new CancelacionDTO(12L, "CANCELADA_INSTITUCION",
                        OffsetDateTime.parse("2026-10-30T09:00:00-03:00"), true));
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(post("/api/medico/consultas/12/cancelar").with(medico)
                        .contentType(MediaType.APPLICATION_JSON).content(CUERPO))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.consultaId").value(12))
                .andExpect(jsonPath("$.estado").value("CANCELADA_INSTITUCION"))
                .andExpect(jsonPath("$.paseDevuelto").value(true));

        verify(service).cancelarConsulta(17L, "12", "Imprevisto");
    }

    @Test
    void medicoCancelaTurnoPropio() throws Exception {
        when(service.cancelarTurno(eq(17L), eq("30"), eq("Imprevisto")))
                .thenReturn(new CancelacionTurnoMedicoDTO(
                        30L, LocalDate.of(2026, 10, 30), "SUSPENDIDO", 2, 1));
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(post("/api/medico/turnos/30/cancelar").with(medico)
                        .contentType(MediaType.APPLICATION_JSON).content(CUERPO))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.turnoId").value(30))
                .andExpect(jsonPath("$.estado").value("SUSPENDIDO"))
                .andExpect(jsonPath("$.consultasCanceladas").value(2))
                .andExpect(jsonPath("$.pasesDevueltos").value(1));

        verify(service).cancelarTurno(17L, "30", "Imprevisto");
    }

    @Test
    void sinMotivoDevuelve400() throws Exception {
        when(service.cancelarConsulta(any(), any(), any()))
                .thenThrow(new uy.edu.proyecto.backend.exception.ApiException(
                        org.springframework.http.HttpStatus.BAD_REQUEST, "VALIDACION",
                        "motivo es obligatorio"));
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(post("/api/medico/consultas/12/cancelar").with(medico)
                        .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));
    }
}
