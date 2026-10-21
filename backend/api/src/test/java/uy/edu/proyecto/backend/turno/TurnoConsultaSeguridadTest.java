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

@WebMvcTest(controllers = TurnoConsultaController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class TurnoConsultaSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TurnoConsultaService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void socioNoPuedeConsultarTurnosDeFuncionario() throws Exception {
        mockMvc.perform(get("/api/turnos")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_SOCIO")
                        )))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/turnos-semanales/4")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_SOCIO")
                        )))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void funcionarioPuedeConsultarListadoYPatron() throws Exception {
        when(service.listar(
                null, null, null, null, null, null,
                null, null, null, null
        )).thenReturn(new TurnosPageResponse(List.of(), 0, 20, 0));
        when(service.obtenerPatron(4L)).thenReturn(
                new uy.edu.proyecto.backend.turno.TurnoSemanalResponse(
                        4L,
                        new TurnoSemanalResponse.MedicoRef(17L, "Marta", "R"),
                        new uy.edu.proyecto.backend.especialidad.Especialidad(
                                3L, "Cardiología", true
                        ),
                        new uy.edu.proyecto.backend.consultorio.Consultorio(
                                5L, "Consultorio 5", "Piso 2"
                        ),
                        2,
                        java.time.LocalDate.of(2026, 10, 20),
                        java.time.LocalDate.of(2026, 12, 15),
                        List.of(),
                        9
                )
        );

        var funcionario = jwt().authorities(
                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
        );
        mockMvc.perform(get("/api/turnos").with(funcionario))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(20))
                .andExpect(jsonPath("$.total").value(0));

        mockMvc.perform(get("/api/turnos-semanales/4").with(funcionario))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(4))
                .andExpect(jsonPath("$.cantidadTurnos").value(9));
    }
}
