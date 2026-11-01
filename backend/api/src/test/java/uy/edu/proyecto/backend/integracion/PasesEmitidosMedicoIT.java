package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-26: pases emitidos por el médico y su situación calculada, contra PostgreSQL real. */
class PasesEmitidosMedicoIT extends BaseIntegracionIT {

    private String tokenMedico() {
        return tokenEmpleado(ciMedico);
    }

    private long sembrarTurnoDe(long medico, LocalDate fecha) {
        long semanal = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, medico, idEspecialidad, idConsultorio, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha) VALUES (?, ?, ?)"
                        + " RETURNING id_turno", Long.class, semanal, idConsultorio, fecha);
        long patron = jdbc.queryForObject(
                "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                        + " VALUES (?, 1, '10:00', '10:20') RETURNING id_numero_semanal",
                Long.class, semanal);
        jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio,"
                + " hora_fin) VALUES (?, ?, 1, '10:00', '10:20')", turno, patron);
        return turno;
    }

    private long sembrarAtencion(long medico, long socio, LocalDate fecha) {
        long turno = sembrarTurnoDe(medico, fecha);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en,"
                        + " resultado_registrado_por, fecha_resultado)"
                        + " VALUES (?, ?, 'ATENDIDA', ?::timestamptz, ?, ?::timestamptz)"
                        + " RETURNING id_consulta",
                Long.class, socio, numeroId(turno, 1),
                fecha.minusDays(1) + "T12:00:00-03:00", medico, fecha + "T12:00:00-03:00");
        return jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion, registrada_en)"
                        + " VALUES (?, ?, 'Control', ?::timestamptz) RETURNING id_atencion",
                Long.class, consulta, medico, fecha + "T12:00:00-03:00");
    }

    private long sembrarPase(long atencion, String emitidoEn, LocalDate venceEl) {
        return jdbc.queryForObject(
                "INSERT INTO pase (id_atencion, id_especialidad_destino, emitido_en, vence_el)"
                        + " VALUES (?, ?, ?::timestamptz, ?) RETURNING id_pase",
                Long.class, atencion, idEspecialidadConPase, emitidoEn, venceEl);
    }

    /** Consulta que usa el pase, con el estado indicado. */
    private void usarPase(long socio, long pase, String estado, LocalDate fechaTurno) {
        long turno = sembrarTurnoDe(idMedico, fechaTurno);
        if ("AGENDADA".equals(estado)) {
            jdbc.update("INSERT INTO consulta (id_socio, id_numero, id_pase) VALUES (?, ?, ?)",
                    socio, numeroId(turno, 1), pase);
        } else {
            // ck_consulta_motivo: CANCELADA_INSTITUCION exige motivo o evento de suspensión.
            jdbc.update("INSERT INTO consulta (id_socio, id_numero, id_pase, estado,"
                            + " cancelada_por, cancelada_en, motivo_cancelacion)"
                            + " VALUES (?, ?, ?, ?, ?, now(), 'motivo')",
                    socio, numeroId(turno, 1), pase, estado, socio);
        }
    }

    private Map<Long, String> situacionesPorId(JsonNode items) {
        Map<Long, String> mapa = new HashMap<>();
        for (JsonNode item : items) {
            mapa.put(item.path("id").asLong(), item.path("situacion").asString());
        }
        return mapa;
    }

    /** Cinco pases del médico: disponible, utilizado, vencido, devuelto y reutilizado.
     *  Cada uno nace de su propia atención (uq_pase_atencion_destino). */
    private Map<String, Long> sembrarPases() {
        Map<String, Long> pases = new HashMap<>();
        pases.put("disponible", sembrarPase(
                sembrarAtencion(idMedico, idSocio1, hoy().minusDays(5)),
                hoy().minusDays(5) + "T12:00:00-03:00", hoy().plusDays(30)));
        pases.put("utilizado", sembrarPase(
                sembrarAtencion(idMedico, idSocio1, hoy().minusDays(6)),
                hoy().minusDays(6) + "T12:00:00-03:00", hoy().plusDays(40)));
        usarPase(idSocio1, pases.get("utilizado"), "AGENDADA", hoy().plusDays(3));
        pases.put("vencido", sembrarPase(
                sembrarAtencion(idMedico, idSocio1, hoy().minusDays(20)),
                hoy().minusDays(20) + "T12:00:00-03:00", hoy().minusDays(1)));
        pases.put("devuelto", sembrarPase(
                sembrarAtencion(idMedico, idSocio1, hoy().minusDays(4)),
                hoy().minusDays(4) + "T12:00:00-03:00", hoy().plusDays(20)));
        usarPase(idSocio1, pases.get("devuelto"), "CANCELADA_SOCIO", hoy().plusDays(4));
        pases.put("reutilizado", sembrarPase(
                sembrarAtencion(idMedico, idSocio1, hoy().minusDays(3)),
                hoy().minusDays(3) + "T12:00:00-03:00", hoy().plusDays(25)));
        usarPase(idSocio1, pases.get("reutilizado"), "CANCELADA_INSTITUCION",
                hoy().plusDays(5));
        usarPase(idSocio1, pases.get("reutilizado"), "AGENDADA", hoy().plusDays(6));
        return pases;
    }

    @Test
    void situacionesSeCalculanDeUsoYVencimiento() {
        Map<String, Long> pases = sembrarPases();

        Respuesta r = get("/api/medico/pases", tokenMedico());

        assertEquals(200, r.estado(), r.cuerpo());
        Map<Long, String> situaciones = situacionesPorId(r.json());
        assertEquals(5, situaciones.size());
        assertEquals("DISPONIBLE", situaciones.get(pases.get("disponible")));
        assertEquals("UTILIZADO", situaciones.get(pases.get("utilizado")));
        assertEquals("VENCIDO", situaciones.get(pases.get("vencido")));
        // La cancelación devuelve el pase vigente (RF-09).
        assertEquals("DISPONIBLE", situaciones.get(pases.get("devuelto")));
        // Utilizado, cancelado y utilizado otra vez: vuelve a estar UTILIZADO.
        assertEquals("UTILIZADO", situaciones.get(pases.get("reutilizado")));
    }

    @Test
    void filtraPorSituacion() {
        Map<String, Long> pases = sembrarPases();
        String medico = tokenMedico();

        Respuesta disponibles = get("/api/medico/pases?situacion=DISPONIBLE", medico);
        Map<Long, String> disp = situacionesPorId(disponibles.json());
        assertEquals(2, disp.size());
        assertTrue(disp.containsKey(pases.get("disponible")));
        assertTrue(disp.containsKey(pases.get("devuelto")));

        Respuesta utilizados = get("/api/medico/pases?situacion=UTILIZADO", medico);
        Map<Long, String> util = situacionesPorId(utilizados.json());
        assertEquals(2, util.size());
        assertTrue(util.containsKey(pases.get("utilizado")));
        assertTrue(util.containsKey(pases.get("reutilizado")));

        Respuesta vencidos = get("/api/medico/pases?situacion=VENCIDO", medico);
        Map<Long, String> venc = situacionesPorId(vencidos.json());
        assertEquals(1, venc.size());
        assertTrue(venc.containsKey(pases.get("vencido")));
    }

    @Test
    void ordenaPorVencimientoPorDefectoYPorEmision() {
        sembrarPases();
        String medico = tokenMedico();

        Respuesta vencimiento = get("/api/medico/pases", medico);
        assertEquals(200, vencimiento.estado(), vencimiento.cuerpo());
        String anterior = "";
        for (JsonNode item : vencimiento.json()) {
            String actual = item.path("venceEl").asString();
            assertTrue(actual.compareTo(anterior) >= 0,
                    "vencimiento ascendente: " + anterior + " -> " + actual);
            anterior = actual;
        }

        Respuesta emision = get("/api/medico/pases?orden=emision&sentido=desc", medico);
        String previo = null;
        for (JsonNode item : emision.json()) {
            String actual = item.path("emitidoEn").asString();
            if (previo != null) {
                assertTrue(actual.compareTo(previo) <= 0,
                        "emision descendente: " + previo + " -> " + actual);
            }
            previo = actual;
        }
    }

    @Test
    void excluyeLosPasesDeOtrosMedicos() {
        sembrarPases();
        // Pase emitido por otro médico.
        String ciOtro = ci(1000099);
        jdbc.update("INSERT INTO persona VALUES (?, 'Otto', 'Medico', DATE '1980-01-01')",
                ciOtro);
        long otro = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion,"
                        + " contrasena_hash, primer_ingreso_completado)"
                        + " VALUES (?, 'MEDICO', ?, '099111222', 'Calle Falsa 123', 'x',"
                        + " TRUE) RETURNING id_cuenta",
                Long.class, ciOtro, "otto@ejemplo.invalid");
        long atencionAjena = sembrarAtencion(otro, idSocio2, hoy().minusDays(2));
        sembrarPase(atencionAjena, hoy().minusDays(2) + "T12:00:00-03:00", hoy().plusDays(60));

        Respuesta r = get("/api/medico/pases", tokenMedico());

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(5, r.json().size());
        // Todos los pacientes son socio1; el pase del otro médico (socio2) no aparece.
        for (JsonNode item : r.json()) {
            assertEquals(ciSocio1, item.path("paciente").path("ci").asString());
        }
    }

    @Test
    void situacionInvalidaDevuelve400() {
        Respuesta r = get("/api/medico/pases?situacion=CANCELADO", tokenMedico());

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
    }

    @Test
    void seguridadSinTokenYRolIncorrecto() {
        assertEquals(401, get("/api/medico/pases", null).estado());
        assertEquals(403, get("/api/medico/pases", tokenSocio(ciSocio1)).estado());
        assertEquals(403, get("/api/medico/pases", tokenEmpleado(ciFuncionario)).estado());
    }
}
