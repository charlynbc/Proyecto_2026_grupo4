package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * RF-20 contra PostgreSQL real. El CI provee DB_URL y carga schema.sql.
 * Cada prueba se ejecuta en una transaccion que Spring revierte al terminar.
 * En local, sin DB_URL, se omite para no depender de servicios externos.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@EnabledIfEnvironmentVariable(named = "DB_URL", matches = "jdbc:postgresql:.*")
class TurnoSemanalPostgresTest {
    private static final ZoneId ZONA = ZoneId.of("America/Montevideo");

    @Autowired
    private JdbcTemplate jdbc;
    @Autowired
    private TurnoSemanalService service;
    @Autowired
    private MockMvc mockMvc;

    private Long patronId;
    private Long funcionarioId;
    private Long consultorioInicial;
    private Long consultorioNuevo;
    private Long primeraFechaId;
    private Long segundaFechaId;
    private Long consultaId;
    private LocalDate primeraFecha;

    @BeforeEach
    void preparar() {
        primeraFecha = LocalDate.now(ZONA).plusDays(1);
        LocalDate segundaFecha = primeraFecha.plusWeeks(1);

        Long medico = crearCuenta("91827361", "MEDICO");
        funcionarioId = crearCuenta("91827362", "FUNCIONARIO");
        Long socio = crearCuenta("91827363", "SOCIO");

        Long especialidad = id(
                "INSERT INTO public.especialidad (nombre, requiere_pase) " +
                        "VALUES ('RF20 prueba PostgreSQL', false) " +
                        "RETURNING id_especialidad"
        );
        jdbc.update(
                "INSERT INTO public.medico_especialidad " +
                        "(id_medico, id_especialidad) VALUES (?, ?)",
                medico, especialidad
        );
        consultorioInicial = id(
                "INSERT INTO public.consultorio (nombre, ubicacion) " +
                        "VALUES ('RF20 origen prueba', 'Piso 1') " +
                        "RETURNING id_consultorio"
        );
        consultorioNuevo = id(
                "INSERT INTO public.consultorio (nombre, ubicacion) " +
                        "VALUES ('RF20 destino prueba', 'Piso 2') " +
                        "RETURNING id_consultorio"
        );
        patronId = id(
                """
                INSERT INTO public.turno_semanal
                    (id_medico, id_especialidad, id_consultorio,
                     id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                RETURNING id_turno_semanal
                """,
                medico, especialidad, consultorioInicial, funcionarioId,
                primeraFecha.getDayOfWeek().getValue(), primeraFecha, segundaFecha
        );
        Long numeroSemanal = id(
                """
                INSERT INTO public.numero_semanal
                    (id_turno_semanal, numero, hora_inicio, hora_fin)
                VALUES (?, 1, TIME '09:00', TIME '09:20')
                RETURNING id_numero_semanal
                """,
                patronId
        );
        primeraFechaId = crearFecha(primeraFecha, numeroSemanal);
        segundaFechaId = crearFecha(segundaFecha, numeroSemanal);
        Long numeroInicial = jdbc.queryForObject(
                "SELECT id_numero FROM public.numero WHERE id_turno = ?",
                Long.class, primeraFechaId
        );
        consultaId = id(
                """
                INSERT INTO public.consulta (id_socio, id_numero)
                VALUES (?, ?) RETURNING id_consulta
                """,
                socio, numeroInicial
        );
    }

    private Long crearCuenta(String ci, String rol) {
        jdbc.update(
                """
                INSERT INTO public.persona
                    (ci, nombre, apellido, fecha_nacimiento)
                VALUES (?, 'Prueba', 'RF20', DATE '1990-01-01')
                """, ci
        );
        return id(
                """
                INSERT INTO public.cuenta
                    (ci, rol, correo, telefono_1)
                VALUES (?, ?, ?, '099000000')
                RETURNING id_cuenta
                """,
                ci, rol, ci + "@rf20.example"
        );
    }

    private Long crearFecha(LocalDate fecha, Long numeroSemanal) {
        Long turnoId = id(
                """
                INSERT INTO public.turno
                    (id_turno_semanal, id_consultorio, fecha)
                VALUES (?, ?, ?)
                RETURNING id_turno
                """,
                patronId, consultorioInicial, fecha
        );
        id(
                """
                INSERT INTO public.numero
                    (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)
                VALUES (?, ?, 1, TIME '09:00', TIME '09:20')
                RETURNING id_numero
                """,
                turnoId, numeroSemanal
        );
        return turnoId;
    }

    private Long id(String sql, Object... args) {
        return jdbc.queryForObject(sql, Long.class, args);
    }

    private Long consultorioDelTurno(Long turnoId) {
        return id(
                "SELECT id_consultorio FROM public.turno WHERE id_turno = ?",
                turnoId
        );
    }

    @Test
    void vistaPreviaLeePostgresYSinEscrituras() {
        var previa = service.vistaPreviaConsultorio(
                patronId, new ModificarTurnoSemanalRequest(consultorioNuevo)
        );
        assertEquals(2, previa.fechas().size());
        assertEquals(primeraFecha, previa.fechas().getFirst().fecha());
        assertEquals(1, previa.fechas().getFirst().consultasAgendadas());
        assertEquals(0, previa.fechas().getLast().consultasAgendadas());
        assertTrue(previa.fechas().stream().allMatch(
                fecha -> fecha.solapamientos().isEmpty()
        ));
        assertEquals(consultorioInicial, consultorioDelTurno(primeraFechaId));
        assertEquals(consultorioInicial, consultorioDelTurno(segundaFechaId));
    }

    @Test
    void dosCambiosParcialesSincronizanPatronSinCancelarConsulta() {
        var primeraRespuesta = service.modificarConsultorio(
                patronId,
                new ModificarTurnoSemanalRequest(
                        consultorioNuevo, List.of(segundaFechaId), false
                )
        );
        assertTrue(primeraRespuesta.consultorioVariaPorFecha());
        assertEquals(consultorioInicial, consultorioDelTurno(primeraFechaId));
        assertEquals(consultorioNuevo, consultorioDelTurno(segundaFechaId));

        var segundaRespuesta = service.modificarConsultorio(
                patronId,
                new ModificarTurnoSemanalRequest(
                        consultorioNuevo, List.of(primeraFechaId), true
                )
        );
        assertEquals(consultorioNuevo, consultorioDelTurno(primeraFechaId));
        assertEquals(consultorioNuevo, consultorioDelTurno(segundaFechaId));
        assertEquals(consultorioNuevo, id(
                "SELECT id_consultorio FROM public.turno_semanal " +
                        "WHERE id_turno_semanal = ?", patronId
        ));
        assertEquals(consultorioNuevo, segundaRespuesta.consultorio().id());
        assertFalse(segundaRespuesta.consultorioVariaPorFecha());
        assertEquals("AGENDADA", jdbc.queryForObject(
                "SELECT estado FROM public.consulta WHERE id_consulta = ?",
                String.class, consultaId
        ));
    }

    /**
     * Regresión RF-20: comprueba el GET HTTP real contra filas PostgreSQL,
     * no solo la respuesta del PATCH ni el SQL leído de manera aislada.
     */
    @Test
    void getDetalleDevuelveConsultorioVariaPorFechaTrasCambioParcial() throws Exception {
        service.modificarConsultorio(
                patronId,
                new ModificarTurnoSemanalRequest(
                        consultorioNuevo, List.of(segundaFechaId), false
                )
        );

        // La fecha no seleccionada todavía conserva el consultorio original.
        assertEquals(consultorioInicial, consultorioDelTurno(primeraFechaId));
        assertEquals(consultorioNuevo, consultorioDelTurno(segundaFechaId));

        mockMvc.perform(get("/api/turnos-semanales/{id}", patronId)
                        .with(jwt()
                                .jwt(token -> token.subject(funcionarioId.toString()))
                                .authorities(new SimpleGrantedAuthority("ROLE_FUNCIONARIO"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.consultorioVariaPorFecha").value(true));
    }

    @Test
    void sinConfirmarConsultaAgendadaSeRechazaSinCambiarDatos() {
        var error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        patronId,
                        new ModificarTurnoSemanalRequest(
                                consultorioNuevo, List.of(primeraFechaId), false
                        )
                )
        );
        assertEquals("TURNO_NO_MODIFICABLE", error.getCode());
        assertEquals(consultorioInicial, consultorioDelTurno(primeraFechaId));
        assertEquals(consultorioInicial, consultorioDelTurno(segundaFechaId));
    }
}
