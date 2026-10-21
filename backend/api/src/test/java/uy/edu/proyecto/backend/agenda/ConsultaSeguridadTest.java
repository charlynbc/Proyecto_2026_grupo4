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
import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = ConsultaController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class ConsultaSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ConsultaService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void solicitudSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(post("/api/consultas")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"numeroId\":4501}"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void funcionarioNoPuedeAgendarComoSocio() throws Exception {
        mockMvc.perform(post("/api/consultas")
                        .with(jwt().jwt(token -> token.subject("31"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                                ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"numeroId\":4501}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void socioPuedeAgendarYRecibeComprobanteDelContrato() throws Exception {
        when(service.agendar(eq(91L), any())).thenReturn(
                new ConsultaDTO(
                        9001L,
                        "AGENDADA",
                        LocalDate.of(2026, 11, 3),
                        2,
                        "09:20",
                        "09:40",
                        new ConsultaDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                        new Especialidad(3L, "Cardiología", true),
                        new Consultorio(5L, "Consultorio 5", "Piso 2"),
                        77L,
                        OffsetDateTime.parse("2026-10-21T15:00:00-03:00"),
                        null,
                        null
                )
        );

        mockMvc.perform(post("/api/consultas")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_SOCIO")
                                ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"numeroId":4501,"paseId":77}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9001))
                .andExpect(jsonPath("$.estado").value("AGENDADA"))
                .andExpect(jsonPath("$.paseId").value(77))
                .andExpect(jsonPath("$.medico.nombre").value("Marta"))
                .andExpect(jsonPath("$.especialidad.requierePase").value(true))
                .andExpect(jsonPath("$.consultorio.ubicacion").value("Piso 2"));

        verify(service).agendar(eq(91L), any(CrearConsultaRequest.class));
    }
}
