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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = TurnoMedicoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class TurnoMedicoSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TurnoMedicoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void socioNoPuedeConsultarTurnosMedicos() throws Exception {
        var socio = jwt().authorities(
                new SimpleGrantedAuthority("ROLE_SOCIO")
        );
        mockMvc.perform(get("/api/medico/turnos")
                        .param("fecha", "2026-10-20")
                        .with(socio))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/medico/turnos/301/numeros")
                        .with(socio))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void medicoPuedeListarSusTurnosYVerNumeros() throws Exception {
        when(service.listar(17L, "2026-10-20"))
                .thenReturn(new TurnosMedicoResponse(List.of()));
        when(service.obtenerNumeros(
                17L, 301L, true, "horaLlegada", "desc"
        )).thenReturn(new NumerosTurnoMedicoResponse(
                new NumerosTurnoMedicoResponse.Turno(
                        301L,
                        java.time.LocalDate.of(2026, 10, 20),
                        null,
                        null,
                        "ACTIVO"
                ),
                List.of()
        ));
        var medico = jwt().jwt(token -> token.subject("17"))
                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"));

        mockMvc.perform(get("/api/medico/turnos")
                        .param("fecha", "2026-10-20")
                        .with(medico))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());
        mockMvc.perform(get("/api/medico/turnos/301/numeros")
                        .param("llegada", "true")
                        .param("orden", "horaLlegada")
                        .param("sentido", "desc")
                        .with(medico))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.turno.id").value(301))
                .andExpect(jsonPath("$.items").isArray());

        verify(service).listar(17L, "2026-10-20");
        verify(service).obtenerNumeros(
                17L, 301L, true, "horaLlegada", "desc"
        );
    }
}
