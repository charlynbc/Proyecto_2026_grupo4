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

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = HistoriaClinicaController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class HistoriaClinicaSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private HistoriaClinicaService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void socioAutenticadoConsultaSuHistoriaConFiltrosDesdeElJwt() throws Exception {
        when(service.listar(
                91L, "2026-01-01", "2026-12-31", "3", "17", "control", null, null
        )).thenReturn(List.of(new HistoriaClinicaDTO(
                5530L,
                LocalDate.parse("2026-10-20"),
                17L,
                "Marta",
                "Rodriguez",
                new Especialidad(3L, "Cardiologia", true),
                "Afeccion ficticia",
                "Tratamiento ficticio",
                "Observacion ficticia",
                List.of()
        )));

        mockMvc.perform(get("/api/historia-clinica")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO")))
                        .param("fechaDesde", "2026-01-01")
                        .param("fechaHasta", "2026-12-31")
                        .param("especialidadId", "3")
                        .param("medicoId", "17")
                        .param("texto", "control"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].idAtencion").value(5530))
                .andExpect(jsonPath("$[0].afeccion").value("Afeccion ficticia"))
                .andExpect(jsonPath("$[0].tratamiento").value("Tratamiento ficticio"))
                .andExpect(jsonPath("$[0].observaciones").value("Observacion ficticia"));

        verify(service).listar(
                eq(91L), eq("2026-01-01"), eq("2026-12-31"),
                eq("3"), eq("17"), eq("control"), eq(null), eq(null)
        );
    }

    @Test
    void socioSoloPuedeVerDetallePropioYElServicioRecibeElSubject() throws Exception {
        when(service.detalle(91L, 5530L)).thenReturn(new HistoriaClinicaDTO(
                5530L,
                LocalDate.parse("2026-10-20"),
                17L,
                "Marta",
                "Rodriguez",
                new Especialidad(3L, "Cardiologia", true),
                "Afeccion ficticia",
                "Tratamiento ficticio",
                null,
                List.of(new HistoriaClinicaDTO.PaseClinicaDTO(
                        78L,
                        new Especialidad(4L, "Nutricion", true),
                        java.time.OffsetDateTime.parse("2026-10-20T09:41:00-03:00"),
                        LocalDate.parse("2027-01-18")
                ))
        ));

        mockMvc.perform(get("/api/historia-clinica/5530")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pases[0].id").value(78))
                .andExpect(jsonPath("$.pases[0].venceEl").value("2027-01-18"));

        verify(service).detalle(91L, 5530L);
    }

    @Test
    void historiaAjenaDevuelve404SinRevelarDatosClinicos() throws Exception {
        when(service.detalle(91L, 991L)).thenThrow(new uy.edu.proyecto.backend.exception.ApiException(
                org.springframework.http.HttpStatus.NOT_FOUND,
                "HISTORIA_NO_ENCONTRADA",
                "La atención no existe o no pertenece a este socio"
        ));

        mockMvc.perform(get("/api/historia-clinica/991")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message").value(
                        "La atención no existe o no pertenece a este socio"
                ))
                .andExpect(jsonPath("$.message").value(
                        org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("Tratamiento ficticio"))
                ));
    }

    @Test
    void identidadJwtInvalidaDevuelve401YNoConsultaServicio() throws Exception {
        mockMvc.perform(get("/api/historia-clinica")
                        .with(jwt().jwt(token -> token.subject("no-es-id"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void otroRolNoPuedeConsultarHistoriaClinica() throws Exception {
        mockMvc.perform(get("/api/historia-clinica/5530")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"))))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void consultaSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/historia-clinica"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void filtroInvalidoSeDevuelveComo400DesdeLaValidacionDelServicio() throws Exception {
        when(service.listar(
                91L, "fecha-invalida", null, null, null, null, null, null
        )).thenThrow(new uy.edu.proyecto.backend.exception.ApiException(
                org.springframework.http.HttpStatus.BAD_REQUEST,
                "VALIDACION",
                "fechaDesde debe tener formato yyyy-MM-dd"
        ));

        mockMvc.perform(get("/api/historia-clinica")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO")))
                        .param("fechaDesde", "fecha-invalida"))
                .andExpect(status().isBadRequest());

        verify(service).listar(
                91L, "fecha-invalida", null, null, null, null, null, null
        );
    }
}
