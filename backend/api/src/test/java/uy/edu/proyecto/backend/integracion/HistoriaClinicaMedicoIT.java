package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

/** RF-22: historia clínica previa del paciente para el médico, contra PostgreSQL real. */
class HistoriaClinicaMedicoIT extends BaseIntegracionIT {

    private String tokenMedico() {
        return tokenEmpleado(ciMedico);
    }

    private Respuesta historia(String token, Object socioId) {
        return get("/api/medico/pacientes/" + socioId + "/historia-clinica", token);
    }

    /** Atención pasada del médico sobre el socio, con un pase emitido. */
    private void sembrarAtencionConPase(long socio) {
        long turnoPasado = sembrarTurno(hoy().minusDays(10), 1);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, estado, resultado_registrado_por,"
                        + " fecha_resultado) VALUES (?, ?, 'ATENDIDA', ?, now())"
                        + " RETURNING id_consulta",
                Long.class, socio, numeroId(turnoPasado, 1), idMedico);
        long atencion = jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion, tratamiento)"
                        + " VALUES (?, ?, 'Afeccion de prueba', 'Tratamiento de prueba')"
                        + " RETURNING id_atencion", Long.class, consulta, idMedico);
        jdbc.update("INSERT INTO pase (id_atencion, id_especialidad_destino, vence_el)"
                        + " VALUES (?, ?, ?)",
                atencion, idEspecialidadConPase, hoy().plusDays(90));
    }

    /** Consulta AGENDADA del socio con el médico en la fecha indicada. */
    private long consultaAgendada(long socio, LocalDate fecha) {
        long turno = sembrarTurno(fecha, 1);
        return sembrarConsulta(socio, numeroId(turno, 1));
    }

    @Test
    void consultaFuturaValidaHabilitaElAcceso() {
        sembrarAtencionConPase(idSocio1);
        consultaAgendada(idSocio1, hoy().plusDays(5));

        Respuesta r = historia(tokenMedico(), idSocio1);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().size());
        assertEquals("Afeccion de prueba", r.json().get(0).path("afeccion").asString());
        assertEquals("Tratamiento de prueba", r.json().get(0).path("tratamiento").asString());
        assertEquals(1, r.json().get(0).path("pases").size());
        assertEquals("Cardiologia", r.json().get(0).path("pases").get(0)
                .path("especialidad").path("nombre").asString());
    }

    @Test
    void consultaDelDiaActualSinAvisoDeLlegadaHabilitaElAcceso() {
        sembrarAtencionConPase(idSocio1);
        consultaAgendada(idSocio1, hoy());
        // Sin aviso de llegada registrado.
        assertEquals(0, contar("aviso_llegada"));

        Respuesta r = historia(tokenMedico(), idSocio1);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().size());
    }

    @Test
    void consultaDeDiaTerminadoNoHabilita() {
        sembrarAtencionConPase(idSocio1);
        // La consulta AGENDADA es de ayer: su día ya terminó.
        consultaAgendada(idSocio1, hoy().minusDays(1));

        Respuesta r = historia(tokenMedico(), idSocio1);

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("NO_ENCONTRADO", r.codigo());
    }

    @Test
    void consultaCanceladaNoHabilita() {
        sembrarAtencionConPase(idSocio1);
        long consulta = consultaAgendada(idSocio1, hoy().plusDays(5));
        jdbc.update("UPDATE consulta SET estado = 'CANCELADA_SOCIO', cancelada_por = ?,"
                + " cancelada_en = now() WHERE id_consulta = ?", idSocio1, consulta);

        Respuesta r = historia(tokenMedico(), idSocio1);

        assertEquals(404, r.estado(), r.cuerpo());
    }

    @Test
    void consultaConOtroMedicoNoHabilita() {
        sembrarAtencionConPase(idSocio1);
        // La consulta agendada del paciente es con otro médico.
        String ciOtro = ci(1000099);
        jdbc.update("INSERT INTO persona VALUES (?, 'Otto', 'Medico', DATE '1980-01-01')", ciOtro);
        long otro = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'MEDICO', ?, '099111222',"
                        + " 'Calle Falsa 123', 'x', TRUE) RETURNING id_cuenta",
                Long.class, ciOtro, "otto@ejemplo.invalid");
        LocalDate fecha = hoy().plusDays(5);
        long semanal = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, otro, idEspecialidad, idConsultorio, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha) VALUES (?, ?, ?)"
                        + " RETURNING id_turno", Long.class, semanal, idConsultorio, fecha);
        long patron = jdbc.queryForObject(
                "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                        + " VALUES (?, 1, '15:00', '15:20') RETURNING id_numero_semanal",
                Long.class, semanal);
        long numero = jdbc.queryForObject(
                "INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                        + " VALUES (?, ?, 1, '15:00', '15:20') RETURNING id_numero",
                Long.class, turno, patron);
        sembrarConsulta(idSocio1, numero);

        Respuesta r = historia(tokenMedico(), idSocio1);

        assertEquals(404, r.estado(), r.cuerpo());
    }

    @Test
    void sinConsultaHabilitanteNoSeRevelaLaHistoria() {
        sembrarAtencionConPase(idSocio1);

        Respuesta r = historia(tokenMedico(), idSocio1);

        assertEquals(404, r.estado(), r.cuerpo());
        assertFalse(r.cuerpo().contains("Afeccion de prueba"), r.cuerpo());
    }

    @Test
    void pacienteInexistenteDevuelve404() {
        Respuesta r = historia(tokenMedico(), 999999);

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("NO_ENCONTRADO", r.codigo());
    }

    @Test
    void propiaHistoriaDevuelve403ConflictoDeInteres() {
        // Cuenta SOCIO con la misma CI del médico autenticado.
        long socioPropio = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'SOCIO', ?, '099111222',"
                        + " 'Calle Falsa 123', 'x', TRUE) RETURNING id_cuenta",
                Long.class, ciMedico, "medico.socio@ejemplo.invalid");
        consultaAgendada(socioPropio, hoy().plusDays(5));

        Respuesta r = historia(tokenMedico(), socioPropio);

        assertEquals(403, r.estado(), r.cuerpo());
        assertEquals("CONFLICTO_DE_INTERES", r.codigo());
    }

    @Test
    void seguridadSinTokenYRolIncorrecto() {
        consultaAgendada(idSocio1, hoy().plusDays(5));

        assertEquals(401, historia(null, idSocio1).estado());
        assertEquals(403, historia(tokenSocio(ciSocio1), idSocio1).estado());
        assertEquals(403, historia(tokenEmpleado(ciFuncionario), idSocio1).estado());
    }

    @Test
    void identificadorInvalidoDevuelve400() {
        Respuesta r = historia(tokenMedico(), "abc");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
    }
}
