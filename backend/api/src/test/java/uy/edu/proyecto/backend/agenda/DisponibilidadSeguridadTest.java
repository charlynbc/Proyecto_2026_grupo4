package uy.edu.proyecto.backend.agenda;

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
import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = DisponibilidadController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class DisponibilidadSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AgendaService agendaService;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void consultaSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/disponibilidad")
                        .param("especialidadId", "3"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(agendaService);
    }

    @Test
    void administradorNoPuedeConsultarDisponibilidadDeSocios() throws Exception {
        mockMvc.perform(get("/api/disponibilidad")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_ADMINISTRADOR")
                                ))
                        .param("especialidadId", "3"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(agendaService);
    }

    @Test
    void socioPuedeConsultarYRecibeLosDatosAnidadosDelContrato() throws Exception {
        when(agendaService.consultarDisponibilidad(
                "3",
                "17",
                "2026-10-20",
                null,
                "fecha",
                "asc"
        )).thenReturn(List.of(new NumeroDisponibleDTO(
                4501L,
                301L,
                2,
                LocalDate.of(2026, 10, 20),
                "09:20",
                "09:40",
                new NumeroDisponibleDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                new Especialidad(3L, "Cardiología", true),
                new Consultorio(5L, "Consultorio 5", "Piso 2")
        )));

        mockMvc.perform(get("/api/disponibilidad")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_SOCIO")
                                ))
                        .param("especialidadId", "3")
                        .param("medicoId", "17")
                        .param("fechaDesde", "2026-10-20")
                        .param("orden", "fecha")
                        .param("sentido", "asc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].numeroId").value(4501))
                .andExpect(jsonPath("$.items[0].turnoId").value(301))
                .andExpect(jsonPath("$.items[0].horaInicio").value("09:20"))
                .andExpect(jsonPath("$.items[0].medico.nombre").value("Marta"))
                .andExpect(jsonPath("$.items[0].especialidad.requierePase").value(true))
                .andExpect(jsonPath("$.items[0].consultorio.ubicacion").value("Piso 2"));

        verify(agendaService).consultarDisponibilidad(
                "3",
                "17",
                "2026-10-20",
                null,
                "fecha",
                "asc"
        );
    }
}
