package uy.edu.proyecto.backend.pase;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.especialidad.Especialidad;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = PaseController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class PaseDisponiblesTest {

    private static final String RUTA = "/api/socios/me/pases/disponibles";

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private PaseService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void sinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get(RUTA)).andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }

    @Test
    void usuarioSinRolSocioDevuelve403() throws Exception {
        mockMvc.perform(get(RUTA)
                        .with(jwt().jwt(token -> token.subject("31"))
                                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO"))))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void socioConPasesRecibeSoloLosCamposDelDtoYUsaSuPropioId() throws Exception {
        when(service.listarDisponibles(91L)).thenReturn(List.of(new PaseDTO(
                77L,
                new Especialidad(3L, "Cardiología", true),
                OffsetDateTime.parse("2026-10-20T14:30:00Z"),
                LocalDate.of(2026, 11, 19)
        )));

        mockMvc.perform(get(RUTA)
                        .param("socioId", "999")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(77))
                .andExpect(jsonPath("$[0].especialidadDestino.id").value(3))
                .andExpect(jsonPath("$[0].especialidadDestino.nombre").value("Cardiología"))
                .andExpect(jsonPath("$[0].emitidoEn").exists())
                .andExpect(jsonPath("$[0].venceEl").value("2026-11-19"))
                .andExpect(jsonPath("$[0].length()").value(4));

        verify(service).listarDisponibles(91L);
    }

    @Test
    void socioSinPasesRecibeListaVacia() throws Exception {
        when(service.listarDisponibles(91L)).thenReturn(List.of());

        mockMvc.perform(get(RUTA)
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void tokenConSujetoInvalidoDevuelve401() throws Exception {
        mockMvc.perform(get(RUTA)
                        .with(jwt().jwt(token -> token.subject("abc"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }

    @Test
    void servicioConsultaConLaFechaDelReloj() {
        PaseRepository repository = mock(PaseRepository.class);
        Clock clock = Clock.fixed(
                Instant.parse("2026-10-25T16:00:00Z"),
                ZoneId.of("America/Montevideo")
        );
        PaseService paseService = new PaseService(repository, clock);

        paseService.listarDisponibles(91L);

        verify(repository).listarDisponibles(91L, LocalDate.of(2026, 10, 25));
    }

    @Test
    void repositorioExcluyeAjenosVencidosYUtilizados() {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        when(jdbcTemplate.query(
                anyString(),
                org.mockito.ArgumentMatchers.<RowMapper<PaseDTO>>any(),
                any(Object[].class)
        )).thenReturn(List.of());

        List<PaseDTO> pases = new PaseRepository(jdbcTemplate)
                .listarDisponibles(91L, LocalDate.of(2026, 10, 25));

        ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
        verify(jdbcTemplate).query(
                sql.capture(),
                org.mockito.ArgumentMatchers.<RowMapper<PaseDTO>>any(),
                any(Object[].class)
        );
        assertTrue(pases.isEmpty());
        assertTrue(sql.getValue().contains("consulta.id_socio = ?"));
        assertTrue(sql.getValue().contains("pase.vence_el >= ?"));
        assertTrue(sql.getValue().contains("NOT EXISTS"));
        assertTrue(sql.getValue().contains("usada.id_pase = pase.id_pase"));
        assertTrue(sql.getValue().contains("'CANCELADA_SOCIO'"));
        assertFalse(sql.getValue().contains("FOR UPDATE"));
    }
}
