package uy.edu.proyecto.backend.estadistica;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.exception.ApiExceptionHandler;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = EstadisticaController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class, ApiExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class EstadisticaSeguridadTest {

    private static final String RUTA = "/api/estadisticas/especialidades";
    private static final String RUTA_TURNOS = "/api/estadisticas/turnos";

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private EstadisticaEspecialidadService service;

    @MockitoBean
    private EstadisticaTurnoService turnoService;

    @MockitoBean
    private EstadisticaConsultaService consultaService;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private static RequestPostProcessor rol(String rol) {
        return jwt().authorities(new SimpleGrantedAuthority("ROLE_" + rol));
    }

    private static EstadisticaTurnoDTO turno(long ofrecidos, long ocupados, String texto) {
        return new EstadisticaTurnoDTO(
                7,
                new EstadisticaTurnoDTO.Persona(5, "Marta", "Medica"),
                new Especialidad(1L, "Medicina General", false),
                new EstadisticaTurnoDTO.Consultorio(3, "Consultorio 1", "Planta baja"),
                2, 2, ofrecidos, ocupados,
                ofrecidos == 0 ? null : java.math.BigDecimal.valueOf(ocupados * 100.0 / ofrecidos),
                texto);
    }

    @Test
    void rf40AdministradorRecibeUtilizacionPorTurnoSinDatosDePacientes() throws Exception {
        when(turnoService.calcular("2026-03-01", "2026-03-31")).thenReturn(
                new EstadisticaTurnoResponse(
                        LocalDate.parse("2026-03-01"),
                        LocalDate.parse("2026-03-31"),
                        List.of(turno(8, 2, "25 %"), turno(0, 0, "Sin datos"))));

        mockMvc.perform(get(RUTA_TURNOS + "?desde=2026-03-01&hasta=2026-03-31").with(rol("ADMINISTRADOR")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].turnoSemanalId").value(7))
                .andExpect(jsonPath("$.items[0].medico.nombre").value("Marta"))
                .andExpect(jsonPath("$.items[0].numerosOfrecidos").value(8))
                .andExpect(jsonPath("$.items[0].numerosOcupados").value(2))
                .andExpect(jsonPath("$.items[0].porcentajeUtilizacion").value(25.0))
                .andExpect(jsonPath("$.items[0].utilizacion").value("25 %"))
                .andExpect(jsonPath("$.items[1].porcentajeUtilizacion").doesNotExist())
                .andExpect(jsonPath("$.items[1].utilizacion").value("Sin datos"))
                .andExpect(jsonPath("$.items[0].socio").doesNotExist())
                .andExpect(jsonPath("$.items[0].ci").doesNotExist());

        verifyNoInteractions(service);
    }

    @Test
    void rf40SocioFuncionarioYMedicoRecibenForbidden() throws Exception {
        for (String rol : List.of("SOCIO", "FUNCIONARIO", "MEDICO")) {
            mockMvc.perform(get(RUTA_TURNOS).with(rol(rol)))
                    .andExpect(status().isForbidden());
        }
        verifyNoInteractions(turnoService);
    }

    @Test
    void rf40SinJwtDevuelve401() throws Exception {
        mockMvc.perform(get(RUTA_TURNOS))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(turnoService);
    }

    @Test
    void rf40FechasInvalidasSeTraducenA400() throws Exception {
        when(turnoService.calcular(any(), any())).thenThrow(new ApiException(
                HttpStatus.BAD_REQUEST, "VALIDACION", "desde debe tener formato YYYY-MM-DD"));

        mockMvc.perform(get(RUTA_TURNOS + "?desde=ayer").with(rol("ADMINISTRADOR")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));
    }

    @Test
    void administradorRecibeLaDemandaPorEspecialidadSinDatosDePacientes() throws Exception {
        when(service.calcular("2026-03-01", "2026-03-31")).thenReturn(
                new EstadisticaEspecialidadResponse(
                        LocalDate.parse("2026-03-01"),
                        LocalDate.parse("2026-03-31"),
                        List.of(
                                new EstadisticaEspecialidadDTO(
                                        new Especialidad(1L, "Medicina General", false), 128),
                                new EstadisticaEspecialidadDTO(
                                        new Especialidad(3L, "Cardiologia", true), 0)
                        )
                ));

        mockMvc.perform(get(RUTA + "?desde=2026-03-01&hasta=2026-03-31").with(rol("ADMINISTRADOR")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.desde").value("2026-03-01"))
                .andExpect(jsonPath("$.hasta").value("2026-03-31"))
                .andExpect(jsonPath("$.items[0].especialidad.id").value(1))
                .andExpect(jsonPath("$.items[0].especialidad.nombre").value("Medicina General"))
                .andExpect(jsonPath("$.items[0].especialidad.requierePase").value(false))
                .andExpect(jsonPath("$.items[0].cantidadConsultas").value(128))
                .andExpect(jsonPath("$.items[1].cantidadConsultas").value(0))
                .andExpect(jsonPath("$.items[0].socio").doesNotExist())
                .andExpect(jsonPath("$.items[0].ci").doesNotExist());

        verify(service).calcular("2026-03-01", "2026-03-31");
    }

    @Test
    void sinParametrosDelegaConNulosParaQueElServicioApliqueElMesEnCurso() throws Exception {
        when(service.calcular(null, null)).thenReturn(new EstadisticaEspecialidadResponse(
                LocalDate.parse("2026-10-01"), LocalDate.parse("2026-10-31"), List.of()));

        mockMvc.perform(get(RUTA).with(rol("ADMINISTRADOR")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isEmpty());

        verify(service).calcular(null, null);
    }

    @Test
    void socioFuncionarioYMedicoRecibenForbiddenSinTocarElServicio() throws Exception {
        for (String rol : List.of("SOCIO", "FUNCIONARIO", "MEDICO")) {
            mockMvc.perform(get(RUTA).with(rol(rol)))
                    .andExpect(status().isForbidden());
        }
        verifyNoInteractions(service);
    }

    @Test
    void sinJwtDevuelve401() throws Exception {
        mockMvc.perform(get(RUTA))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void errorDeValidacionDelServicioSeTraduceA400() throws Exception {
        when(service.calcular(any(), any())).thenThrow(new ApiException(
                HttpStatus.BAD_REQUEST, "VALIDACION", "desde no puede ser posterior a hasta"));

        mockMvc.perform(get(RUTA + "?desde=2026-03-31&hasta=2026-03-01").with(rol("ADMINISTRADOR")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));
    }

    @Test
    void soloSeExponeLecturaYLasSubrutasNoDefinidasNoSonAccesiblesPorOtrosRoles() throws Exception {
        mockMvc.perform(post(RUTA).with(rol("ADMINISTRADOR")))
                .andExpect(status().is4xxClientError());

        mockMvc.perform(get("/api/estadisticas/otra").with(rol("SOCIO")))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    private static final String RUTA_CONSULTAS = "/api/estadisticas/consultas";

    @Test
    void rf41AdministradorRecibeConteosPorEstadoSinDatosDePacientes() throws Exception {
        java.util.Map<String, Long> estados = new java.util.LinkedHashMap<>();
        for (String estado : EstadisticaConsultaService.ESTADOS) {
            estados.put(estado, 0L);
        }
        estados.put("AGENDADA", 3L);
        estados.put("CANCELADA_SOCIO", 1L);
        when(consultaService.calcular("2026-03-01", "2026-03-31")).thenReturn(
                new EstadisticaConsultaResponse(
                        LocalDate.parse("2026-03-01"), LocalDate.parse("2026-03-31"),
                        estados, 4, 1, java.math.BigDecimal.valueOf(25.00), "25 %"));

        mockMvc.perform(get(RUTA_CONSULTAS + "?desde=2026-03-01&hasta=2026-03-31").with(rol("ADMINISTRADOR")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.desde").value("2026-03-01"))
                .andExpect(jsonPath("$.estados.AGENDADA").value(3))
                .andExpect(jsonPath("$.estados.NO_SE_PRESENTO").value(0))
                .andExpect(jsonPath("$.totalConsultas").value(4))
                .andExpect(jsonPath("$.canceladasPorSocio").value(1))
                .andExpect(jsonPath("$.porcentajeCancelacion").value(25.0))
                .andExpect(jsonPath("$.porcentajeCancelacionTexto").value("25 %"))
                .andExpect(jsonPath("$.socio").doesNotExist())
                .andExpect(jsonPath("$.items").doesNotExist());

        verifyNoInteractions(service, turnoService);
    }

    @Test
    void rf41SocioFuncionarioYMedicoRecibenForbidden() throws Exception {
        for (String rol : List.of("SOCIO", "FUNCIONARIO", "MEDICO")) {
            mockMvc.perform(get(RUTA_CONSULTAS).with(rol(rol)))
                    .andExpect(status().isForbidden());
        }
        verifyNoInteractions(consultaService);
    }

    @Test
    void rf41SinJwtDevuelve401() throws Exception {
        mockMvc.perform(get(RUTA_CONSULTAS))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(consultaService);
    }

    @Test
    void rf41FechasInvalidasSeTraducenA400ConCodigoValidacion() throws Exception {
        when(consultaService.calcular(any(), any())).thenThrow(new ApiException(
                HttpStatus.BAD_REQUEST, "VALIDACION", "desde debe tener formato YYYY-MM-DD"));

        mockMvc.perform(get(RUTA_CONSULTAS + "?desde=ayer").with(rol("ADMINISTRADOR")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));
    }

    @Test
    void rf41SoloSeExponeLectura() throws Exception {
        mockMvc.perform(post(RUTA_CONSULTAS).with(rol("ADMINISTRADOR")))
                .andExpect(status().is4xxClientError());
        verifyNoInteractions(consultaService);
    }
}
