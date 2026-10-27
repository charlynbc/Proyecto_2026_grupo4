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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
    private ConsultaHistorialService historialService;

    @MockitoBean
    private CancelacionService cancelacionService;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void cancelarSinJwtDevuelve401() throws Exception {
        mockMvc.perform(post("/api/consultas/9001/cancelar"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(cancelacionService);
    }

    @Test
    void cancelarRechazaRolesDeEmpleado() throws Exception {
        for (String rol : new String[] {"FUNCIONARIO", "MEDICO", "ADMINISTRADOR"}) {
            mockMvc.perform(post("/api/consultas/9001/cancelar")
                            .with(jwt().jwt(token -> token.subject("31"))
                                    .authorities(new SimpleGrantedAuthority("ROLE_" + rol))))
                    .andExpect(status().isForbidden());
        }

        verifyNoInteractions(cancelacionService);
    }

    @Test
    void socioCancelaConSuIdentidadDelJwt() throws Exception {
        OffsetDateTime cancelada = OffsetDateTime.parse("2026-10-15T08:03:10-03:00");
        when(cancelacionService.cancelarPorSocio(eq(91L), eq("9001")))
                .thenReturn(new CancelacionDTO(9001L, "CANCELADA_SOCIO", cancelada, true));

        mockMvc.perform(post("/api/consultas/9001/cancelar")
                        .param("socioId", "1")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.consultaId").value(9001))
                .andExpect(jsonPath("$.estado").value("CANCELADA_SOCIO"))
                .andExpect(jsonPath("$.paseDevuelto").value(true));

        verify(cancelacionService).cancelarPorSocio(91L, "9001");
    }

    @Test
    void cancelarPorGetNoEstaPermitido() throws Exception {
        mockMvc.perform(get("/api/consultas/9001/cancelar")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().is4xxClientError());

        verifyNoInteractions(cancelacionService);
    }

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
    void historialExigeAutenticacion() throws Exception {
        mockMvc.perform(get("/api/consultas"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(historialService);
    }

    @Test
    void empleadoNoPuedeLeerHistorialDeSocio() throws Exception {
        mockMvc.perform(get("/api/consultas")
                        .with(jwt().jwt(token -> token.subject("31"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                                )))
                .andExpect(status().isForbidden());

        verifyNoInteractions(historialService);
    }

    @Test
    void socioPuedeListarSuHistorialConFiltros() throws Exception {
        when(historialService.listar(
                eq(91L),
                eq("NO_ASISTIO"),
                eq("2026-10-01"),
                eq("2026-10-31"),
                eq("3"),
                eq("17"),
                eq("especialidad"),
                eq("asc"),
                eq("1"),
                eq("10")
        )).thenReturn(new ConsultaHistorialPageResponse(
                java.util.List.of(consulta("NO_ASISTIO")),
                1,
                10,
                1
        ));

        mockMvc.perform(get("/api/consultas")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_SOCIO")
                                ))
                        .param("estado", "NO_ASISTIO")
                        .param("fechaDesde", "2026-10-01")
                        .param("fechaHasta", "2026-10-31")
                        .param("especialidadId", "3")
                        .param("medicoId", "17")
                        .param("orden", "especialidad")
                        .param("sentido", "asc")
                        .param("page", "1")
                        .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.size").value(10))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.items[0].id").value(9001))
                .andExpect(jsonPath("$.items[0].estado").value("NO_ASISTIO"))
                .andExpect(jsonPath("$.items[0].medico.apellido").value("Rodríguez"))
                .andExpect(jsonPath("$.items[0].especialidad.nombre").value("Cardiología"))
                .andExpect(jsonPath("$.items[0].consultorio.nombre").value("Consultorio 5"));

        org.mockito.Mockito.verify(historialService).listar(
                eq(91L),
                eq("NO_ASISTIO"),
                eq("2026-10-01"),
                eq("2026-10-31"),
                eq("3"),
                eq("17"),
                eq("especialidad"),
                eq("asc"),
                eq("1"),
                eq("10")
        );
    }

    @Test
    void socioPuedePedirDetallePeroSinRevelarOtrasCuentas() throws Exception {
        when(historialService.obtener(91L, "9001")).thenThrow(
                new uy.edu.proyecto.backend.exception.ApiException(
                        org.springframework.http.HttpStatus.NOT_FOUND,
                        "NO_ENCONTRADO",
                        "No existe la consulta indicada"
                )
        );
        mockMvc.perform(get("/api/consultas/9001")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_SOCIO")
                                )))
                .andExpect(status().isNotFound());

        verify(historialService).obtener(91L, "9001");
    }

    @Test
    void socioPuedeObtenerDetalleConLaFormaConsultaDTO() throws Exception {
        when(historialService.obtener(91L, "9001"))
                .thenReturn(consulta("ATENDIDA"));

        mockMvc.perform(get("/api/consultas/9001")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(
                                        new SimpleGrantedAuthority("ROLE_SOCIO")
                                )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(9001))
                .andExpect(jsonPath("$.estado").value("ATENDIDA"))
                .andExpect(jsonPath("$.fecha").value("2026-10-20"))
                .andExpect(jsonPath("$.horaInicio").value("09:20"))
                .andExpect(jsonPath("$.medico.nombre").value("Marta"))
                .andExpect(jsonPath("$.especialidad.requierePase").value(true))
                .andExpect(jsonPath("$.consultorio.ubicacion").value("Piso 2"))
                .andExpect(jsonPath("$.agendadaEn").value(
                        "2026-10-14T10:12:45-03:00"
                ));
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

    private ConsultaDTO consulta(String estado) {
        return new ConsultaDTO(
                9001L,
                estado,
                LocalDate.of(2026, 10, 20),
                2,
                "09:20",
                "09:40",
                new ConsultaDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                new Especialidad(3L, "Cardiología", true),
                new Consultorio(5L, "Consultorio 5", "Piso 2"),
                null,
                OffsetDateTime.parse("2026-10-14T10:12:45-03:00"),
                null,
                null
        );
    }
}
