package uy.edu.proyecto.backend.aviso;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

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

import uy.edu.proyecto.backend.agenda.ConsultaDTO;
import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AvisoLlegadaController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AvisoLlegadaSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AvisoLlegadaService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void socioNoPuedeUsarLasOperacionesDeLlegada() throws Exception {
        var socio = jwt().authorities(
                new SimpleGrantedAuthority("ROLE_SOCIO")
        );
        mockMvc.perform(get("/api/avisos-llegada/consultas-hoy")
                        .with(socio)
                        .param("ci", "67890127"))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/avisos-llegada")
                        .with(socio)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ci\":\"67890127\"}"))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void funcionarioPuedeBuscarConsultasDeHoy() throws Exception {
        when(service.consultasDeHoy("67890127")).thenReturn(List.of(
                new ConsultaDTO(
                        9001L,
                        "AGENDADA",
                        LocalDate.of(2026, 10, 21),
                        2,
                        "09:20",
                        "09:40",
                        new ConsultaDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                        new Especialidad(3L, "Cardiología", true),
                        new Consultorio(5L, "Consultorio 5", "Piso 2"),
                        77L,
                        OffsetDateTime.parse("2026-10-14T10:12:45-03:00"),
                        null,
                        null
                )
        ));

        mockMvc.perform(get("/api/avisos-llegada/consultas-hoy")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                        ))
                        .param("ci", "67890127"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].estado").value("AGENDADA"))
                .andExpect(jsonPath("$.items[0].consultorio.nombre")
                        .value("Consultorio 5"));

        verify(service).consultasDeHoy("67890127");
    }

    @Test
    void funcionarioRecibe201AlCrearY200SiElAvisoYaExistia() throws Exception {
        AvisoLlegadaDTO original = new AvisoLlegadaDTO(
                7001L,
                new AvisoLlegadaDTO.SocioRef(
                        "67890127", "Lucía", "Fernández"
                ),
                LocalDate.of(2026, 10, 21),
                OffsetDateTime.parse("2026-10-21T08:55:12-03:00"),
                new AvisoLlegadaDTO.FuncionarioRef(
                        31L, "Pablo", "Gómez"
                )
        );
        when(service.registrar("67890127", 31L))
                .thenReturn(new ResultadoAvisoLlegada(original, true));
        when(service.registrar("67890127", 32L))
                .thenReturn(new ResultadoAvisoLlegada(original, false));

        var funcionario31 = jwt().jwt(token -> token.subject("31"))
                .authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"));
        mockMvc.perform(post("/api/avisos-llegada")
                        .with(funcionario31)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ci\":\"67890127\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7001))
                .andExpect(jsonPath("$.registradaPor.id").value(31));

        mockMvc.perform(post("/api/avisos-llegada")
                        .with(jwt().jwt(token -> token.subject("32"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                                ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ci\":\"67890127\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.registradaEn").value(
                        "2026-10-21T08:55:12-03:00"
                ))
                .andExpect(jsonPath("$.registradaPor.id").value(31));

        verify(service).registrar(eq("67890127"), eq(31L));
        verify(service).registrar(eq("67890127"), eq(32L));
    }
}
