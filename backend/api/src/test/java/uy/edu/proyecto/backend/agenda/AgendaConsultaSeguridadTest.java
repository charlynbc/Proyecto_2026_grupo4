package uy.edu.proyecto.backend.agenda;

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

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AgendaConsultaController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AgendaConsultaSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AgendaConsultaService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void requiereAutenticacion() throws Exception {
        mockMvc.perform(get("/api/agendas"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void permiteSoloAlFuncionario() throws Exception {
        for (String rol : new String[]{
                "SOCIO", "MEDICO", "ADMINISTRADOR"
        }) {
            mockMvc.perform(get("/api/agendas")
                            .with(jwt().authorities(
                                    new SimpleGrantedAuthority("ROLE_" + rol)
                            )))
                    .andExpect(status().isForbidden());
        }
        verifyNoInteractions(service);

        when(service.consultar(
                null, null, null, null, null, null, null, null, null, null
        )).thenReturn(new AgendaOperativaPageResponse(
                java.util.List.of(), 0, 20, 0
        ));
        mockMvc.perform(get("/api/agendas")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                        )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(20))
                .andExpect(jsonPath("$.total").value(0));

        verify(service).consultar(
                null, null, null, null, null, null, null, null, null, null
        );
    }

    @Test
    void respondeSoloConDatosOperativosDelContrato() throws Exception {
        AgendaOperativaDTO item = new AgendaOperativaDTO(
                9001L,
                new AgendaOperativaDTO.Socio("45678911", "Lucía", "Fernández"),
                new AgendaOperativaDTO.Medico(17L, "Marta", "Rodríguez"),
                new AgendaOperativaDTO.Especialidad(3L, "Cardiología", true),
                LocalDate.of(2026, 10, 23),
                "09:20",
                "09:40",
                new AgendaOperativaDTO.Consultorio(5L, "Consultorio 5", "Piso 2"),
                "AGENDADA",
                OffsetDateTime.parse("2026-10-23T08:55:12-03:00")
        );
        when(service.consultar(
                null, null, null, null, null, null, null, null, null, null
        )).thenReturn(new AgendaOperativaPageResponse(List.of(item), 0, 20, 1));

        String respuesta = mockMvc.perform(get("/api/agendas")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                        )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].consultaId").value(9001))
                .andExpect(jsonPath("$.items[0].socio.ci").value("45678911"))
                .andExpect(jsonPath("$.items[0].fecha").value("2026-10-23"))
                .andExpect(jsonPath("$.items[0].llegadaEn")
                        .value("2026-10-23T08:55:12-03:00"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        org.junit.jupiter.api.Assertions.assertFalse(respuesta.contains("contrasena"));
        org.junit.jupiter.api.Assertions.assertFalse(respuesta.contains("afeccion"));
        org.junit.jupiter.api.Assertions.assertFalse(respuesta.contains("tratamiento"));
        org.junit.jupiter.api.Assertions.assertFalse(respuesta.contains("historiaClinica"));
    }
}
