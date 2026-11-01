package uy.edu.proyecto.backend.turno;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = TurnoSemanalController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class TurnoSemanalSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private TurnoSemanalService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void solicitudSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(post("/api/turnos-semanales")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void socioNoPuedeCrearTurnosSemanales() throws Exception {
        mockMvc.perform(post("/api/turnos-semanales")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void administradorNoPuedeCrearTurnosSemanales() throws Exception {
        mockMvc.perform(post("/api/turnos-semanales")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_ADMINISTRADOR")
                                ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void funcionarioPuedeCrearTurnoSemanal() throws Exception {
        when(service.crear(any(), eq(91L))).thenReturn(
                new TurnoSemanalResponse(
                        41L,
                        new TurnoSemanalResponse.MedicoRef(17L, "Ana", "Pérez"),
                        new uy.edu.proyecto.backend.especialidad.Especialidad(
                                3L, "Cardiología", true
                        ),
                        new uy.edu.proyecto.backend.consultorio.Consultorio(
                                5L, "Consultorio 2", "Piso 1"
                        ),
                        2,
                        java.time.LocalDate.of(2026, 10, 20),
                        java.time.LocalDate.of(2026, 10, 27),
                        java.util.List.of(
                                new TurnoSemanalResponse.NumeroSemanalResponse(
                                        1, "09:00", "09:20"
                                )
                        ),
                        2
                )
        );

        mockMvc.perform(post("/api/turnos-semanales")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                                ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "medicoId":17,
                                  "especialidadId":3,
                                  "consultorioId":5,
                                  "diaSemana":2,
                                  "fechaInicio":"2026-10-20",
                                  "fechaFin":"2026-10-27",
                                  "numeros":[
                                    {"numero":1,"horaInicio":"09:00","horaFin":"09:20"}
                                  ]
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(41))
                .andExpect(jsonPath("$.medico.nombre").value("Ana"))
                .andExpect(jsonPath("$.especialidad.requierePase").value(true))
                .andExpect(jsonPath("$.consultorio.ubicacion").value("Piso 1"))
                .andExpect(jsonPath("$.cantidadTurnos").value(2));

        verify(service).crear(any(), eq(91L));
    }

    @Test
    void modificarTurnoSemanalSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(patch("/api/turnos-semanales/41")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"consultorioId\":7}"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void socioNoPuedeModificarTurnosSemanales() throws Exception {
        mockMvc.perform(patch("/api/turnos-semanales/41")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"consultorioId\":7}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void administradorNoPuedeModificarTurnosSemanales() throws Exception {
        mockMvc.perform(patch("/api/turnos-semanales/41")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_ADMINISTRADOR")
                                ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"consultorioId\":7}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void funcionarioPuedeModificarElConsultorio() throws Exception {
        when(service.modificarConsultorio(eq(41L), any())).thenReturn(
                new TurnoSemanalResponse(
                        41L,
                        new TurnoSemanalResponse.MedicoRef(17L, "Ana", "Pérez"),
                        new uy.edu.proyecto.backend.especialidad.Especialidad(
                                3L, "Cardiología", true
                        ),
                        new uy.edu.proyecto.backend.consultorio.Consultorio(
                                7L, "Consultorio 7", "Piso 2"
                        ),
                        2,
                        java.time.LocalDate.of(2026, 10, 20),
                        java.time.LocalDate.of(2026, 10, 27),
                        java.util.List.of(
                                new TurnoSemanalResponse.NumeroSemanalResponse(
                                        1, "09:00", "09:20"
                                )
                        ),
                        2
                )
        );

        mockMvc.perform(patch("/api/turnos-semanales/41")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                                ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"consultorioId\":7}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(41))
                .andExpect(jsonPath("$.consultorio.id").value(7));

        verify(service).modificarConsultorio(eq(41L), any());
    }
}
