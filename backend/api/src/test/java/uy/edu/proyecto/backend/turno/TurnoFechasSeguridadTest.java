package uy.edu.proyecto.backend.turno;

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

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

@WebMvcTest(controllers = TurnoFechasController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class TurnoFechasSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TurnoFechasService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void socioNoPuedeUsarNingunoDeLosEndpoints() throws Exception {
        var socio = jwt().authorities(
                new SimpleGrantedAuthority("ROLE_SOCIO")
        );
        String cuerpoPreview = """
                {"ids":[301]}
                """;
        String cuerpoCambios = """
                {"filtro":{"medicoId":17,"especialidadId":3,
                 "fechaDesde":"2026-10-21","fechaHasta":"2026-10-21"},
                 "ids":[301],"cantidadConfirmada":0}
                """;

        mockMvc.perform(post("/api/turnos/suspensiones/previsualizar")
                        .with(socio)
                        .contentType("application/json")
                        .content(cuerpoPreview))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/turnos/suspensiones")
                        .with(socio)
                        .contentType("application/json")
                        .content(cuerpoCambios))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/turnos/rehabilitaciones")
                        .with(socio)
                        .contentType("application/json")
                        .content(cuerpoCambios))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void funcionarioPuedeAccederYSeUsaElSubjectDelJwt() throws Exception {
        var funcionario = jwt()
                .jwt(token -> token.subject("41"))
                .authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"));
        when(service.previsualizar(
                new PrevisualizarSuspensionRequest(List.of(301L))
        )).thenReturn(new VistaPreviaSuspensionDTO(List.of(), 0));
        when(service.suspender(
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.eq(41L)
        )).thenReturn(new ResultadoFechasDTO(List.of(), 0));
        when(service.rehabilitar(
                org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.eq(41L)
        )).thenReturn(new ResultadoFechasDTO(List.of(), 0));
        String cuerpoPreview = """
                {"ids":[301]}
                """;
        String cuerpoCambios = """
                {"filtro":{"medicoId":17,"especialidadId":3,
                 "fechaDesde":"2026-10-21","fechaHasta":"2026-10-21"},
                 "ids":[301],"cantidadConfirmada":0}
                """;

        mockMvc.perform(post("/api/turnos/suspensiones/previsualizar")
                        .with(funcionario)
                        .contentType("application/json")
                        .content(cuerpoPreview))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/turnos/suspensiones")
                        .with(funcionario)
                        .contentType("application/json")
                        .content(cuerpoCambios))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/turnos/rehabilitaciones")
                        .with(funcionario)
                        .contentType("application/json")
                        .content(cuerpoCambios))
                .andExpect(status().isOk());

        verify(service).previsualizar(new PrevisualizarSuspensionRequest(List.of(301L)));
        verify(service).suspender(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.eq(41L));
        verify(service).rehabilitar(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.eq(41L));
    }

    @Test
    void cuerpoMalFormadoDevuelveErrorContractualDeValidacion() throws Exception {
        mockMvc.perform(post("/api/turnos/suspensiones/previsualizar")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                        ))
                        .contentType("application/json")
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verifyNoInteractions(service);
    }
}
