package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-13, RF-08, RF-09, RF-11, RF-14 y RF-15 contra PostgreSQL real, por la API HTTP. */
class CircuitoConsultasIT extends BaseIntegracionIT {

    private final LocalDate fecha = hoy().plusDays(7);

    private Respuesta reservar(String token, long numeroId) {
        return post("/api/consultas", token, "{\"numeroId\":%d}".formatted(numeroId));
    }

    private String turnoEstado(long turnoId) {
        return jdbc.queryForObject("SELECT estado FROM turno WHERE id_turno = ?", String.class, turnoId);
    }

    private Respuesta suspender(String token, long turnoId, Integer confirmada) {
        return post("/api/turnos/suspensiones", token, """
                {"filtro":%s,"ids":[%d],"observacion":"Medico en congreso","cantidadConfirmada":%s}
                """.formatted(filtro(), turnoId, confirmada));
    }

    private String filtro() {
        return "{\"medicoId\":%d,\"especialidadId\":%d,\"fechaDesde\":\"%s\",\"fechaHasta\":\"%s\"}"
                .formatted(idMedico, idEspecialidad, fecha.minusDays(1), fecha.plusDays(1));
    }

    private Respuesta rehabilitar(String token, long turnoId) {
        return post("/api/turnos/rehabilitaciones", token,
                "{\"filtro\":%s,\"ids\":[%d]}".formatted(filtro(), turnoId));
    }

    @Test
    void rf13TurnoSemanalGeneraTurnoYNumerosYRechazaSolapamientoYEspecialidadAjena() {
        String funcionario = tokenEmpleado(ciFuncionario);
        long turno = crearTurnoPorApi(funcionario, fecha, 3);

        assertEquals("ACTIVO", turnoEstado(turno));
        assertEquals(3, jdbc.queryForObject(
                "SELECT count(*) FROM numero WHERE id_turno = ?", Integer.class, turno));

        Respuesta solapado = post("/api/turnos-semanales", funcionario, """
                {"medicoId":%d,"especialidadId":%d,"consultorioId":%d,"diaSemana":%d,
                 "fechaInicio":"%s","fechaFin":"%s",
                 "numeros":[{"numero":1,"horaInicio":"09:10","horaFin":"09:30"}]}
                """.formatted(idMedico, idEspecialidad, idConsultorio, diaSemana(fecha), fecha, fecha));
        assertEquals(409, solapado.estado());
        assertEquals("SOLAPAMIENTO_TURNO", solapado.codigo());

        Respuesta ajena = post("/api/turnos-semanales", funcionario, """
                {"medicoId":%d,"especialidadId":%d,"consultorioId":%d,"diaSemana":%d,
                 "fechaInicio":"%s","fechaFin":"%s",
                 "numeros":[{"numero":1,"horaInicio":"15:00","horaFin":"15:20"}]}
                """.formatted(idMedico, idEspecialidadConPase, idConsultorio, diaSemana(fecha),
                fecha, fecha));
        assertTrue(ajena.estado() >= 400 && ajena.estado() < 500, "estado " + ajena.estado());
        assertEquals("ESPECIALIDAD_NO_DEL_MEDICO", ajena.codigo());

        assertEquals(1, contar("turno_semanal"));
        assertEquals(1, contar("turno"));
        assertEquals(3, contar("numero"));
    }

    @Test
    void rf08Rf09Rf11DisponibilidadReservaEHistorial() {
        long turno = crearTurnoPorApi(tokenEmpleado(ciFuncionario), fecha, 3);
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);

        Respuesta disponibles = get("/api/disponibilidad?especialidadId=" + idEspecialidad, socio1);
        assertEquals(200, disponibles.estado());
        JsonNode items = disponibles.json().path("items");
        assertEquals(3, items.size());
        assertEquals(fecha.toString(), items.get(0).path("fecha").asString());

        long primero = numeroId(turno, 1);
        Respuesta reserva = reservar(socio1, primero);
        assertEquals(201, reserva.estado(), reserva.cuerpo());
        assertEquals("AGENDADA", reserva.json().path("estado").asString());
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_socio = ? AND id_numero = ? AND estado = 'AGENDADA'",
                Integer.class, idSocio1, primero));
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE tipo = 'AGENDA'", Integer.class));

        Respuesta tomado = reservar(socio2, primero);
        assertEquals(409, tomado.estado());
        assertEquals("NUMERO_NO_DISPONIBLE", tomado.codigo());

        Respuesta otraMismaEspecialidad = reservar(socio1, numeroId(turno, 2));
        assertEquals(409, otraMismaEspecialidad.estado());
        assertEquals("LIMITE_ESPECIALIDAD", otraMismaEspecialidad.codigo());

        assertEquals(2, get("/api/disponibilidad?especialidadId=" + idEspecialidad, socio2)
                .json().path("items").size());

        Respuesta historial = get("/api/consultas", socio1);
        assertEquals(200, historial.estado());
        assertEquals(1, historial.json().path("items").size());
        assertEquals("AGENDADA", historial.json().path("items").get(0).path("estado").asString());
        assertEquals(0, get("/api/consultas", socio2).json().path("items").size(),
                "Un socio no ve las consultas de otro");
        assertEquals(200, get("/api/consultas?estado=CANCELADA_SOCIO", socio1).estado());
    }

    @Test
    void rf09RechazaNumeroConMenosDeDosHorasDeAnticipacionYEspecialidadConPaseSinPase() {
        String socio1 = tokenSocio(ciSocio1);
        long turnoHoy = sembrarTurno(hoy(), 1);
        jdbc.update("UPDATE numero SET hora_inicio = '00:05', hora_fin = '00:25' WHERE id_turno = ?", turnoHoy);
        Respuesta pronto = reservar(socio1, numeroId(turnoHoy, 1));
        assertEquals(409, pronto.estado(), pronto.cuerpo());
        assertEquals("ANTICIPACION_INVALIDA", pronto.codigo());
        assertEquals(0, contar("consulta"));

        long turnoPase = sembrarTurno(fecha, 1);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ? WHERE id_turno_semanal"
                + " = (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)",
                idEspecialidadConPase, turnoPase);
        Respuesta sinPase = reservar(socio1, numeroId(turnoPase, 1));
        assertTrue(sinPase.estado() >= 400 && sinPase.estado() < 500, "estado " + sinPase.estado());
        assertEquals(0, contar("consulta"));
    }

    @Test
    void rf14Rf15SuspensionCancelaConsultasYNotificaYRehabilitacionNoLasRestaura() {
        String funcionario = tokenEmpleado(ciFuncionario);
        long turno = crearTurnoPorApi(funcionario, fecha, 3);
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        assertEquals(201, reservar(socio1, numeroId(turno, 1)).estado());
        assertEquals(201, reservar(socio2, numeroId(turno, 2)).estado());

        Respuesta vista = post("/api/turnos/suspensiones/previsualizar", funcionario,
                "{\"ids\":[%d]}".formatted(turno));
        assertEquals(200, vista.estado(), vista.cuerpo());
        assertEquals(turno, vista.json().path("fechasAfectadas").get(0).path("turnoId").asLong());
        assertEquals("ACTIVO", turnoEstado(turno), "Previsualizar no modifica nada");
        int consultasAfectadas = vista.json().path("fechasAfectadas").get(0).path("consultasACancelar").asInt();
        assertEquals(2, consultasAfectadas);
        int totalConfirmar = vista.json().path("cantidadConsultasACancelar").asInt();
        assertEquals(2, totalConfirmar);

        Respuesta desactualizada = suspender(funcionario, turno, totalConfirmar + 1);
        assertEquals(409, desactualizada.estado());
        assertEquals("CONFIRMACION_DESACTUALIZADA", desactualizada.codigo());
        assertEquals("ACTIVO", turnoEstado(turno));
        assertEquals(0, contar("turno_evento"));
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE estado = 'AGENDADA'", Integer.class));

        Respuesta suspension = suspender(funcionario, turno, totalConfirmar);
        assertEquals(200, suspension.estado(), suspension.cuerpo());
        assertEquals(2, suspension.json().path("consultasCanceladas").asInt());
        assertEquals("SUSPENDIDO", turnoEstado(turno));
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE estado = 'CANCELADA_INSTITUCION'"
                        + " AND id_evento_suspension IS NOT NULL", Integer.class));
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE tipo = 'SUSPENSION'", Integer.class));
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM turno_evento WHERE tipo = 'SUSPENSION'", Integer.class));

        assertEquals(0, get("/api/disponibilidad?especialidadId=" + idEspecialidad, socio1)
                .json().path("items").size());
        Respuesta sobreSuspendido = reservar(tokenSocio(ciSocio3), numeroId(turno, 3));
        assertEquals(409, sobreSuspendido.estado());
        assertEquals("NUMERO_NO_DISPONIBLE", sobreSuspendido.codigo());

        Respuesta repetida = suspender(funcionario, turno, 0);
        assertEquals(409, repetida.estado());
        assertEquals("TURNO_NO_SUSPENDIBLE", repetida.codigo());

        Respuesta rehabilitacion = rehabilitar(funcionario, turno);
        assertEquals(200, rehabilitacion.estado(), rehabilitacion.cuerpo());
        assertEquals("ACTIVO", turnoEstado(turno));
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE estado = 'CANCELADA_INSTITUCION'", Integer.class),
                "Las consultas canceladas no se restauran");
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE estado = 'AGENDADA'", Integer.class));
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM turno_evento WHERE tipo = 'REHABILITACION'", Integer.class));

        assertEquals(3, get("/api/disponibilidad?especialidadId=" + idEspecialidad, socio1)
                .json().path("items").size());
        assertEquals(201, reservar(socio1, numeroId(turno, 1)).estado(),
                "Tras rehabilitar, el socio puede volver a reservar");

        Respuesta noRehabilitable = rehabilitar(funcionario, turno);
        assertEquals(409, noRehabilitable.estado());
        assertEquals("TURNO_NO_REHABILITABLE", noRehabilitable.codigo());

        Respuesta historial = get("/api/consultas?estado=CANCELADA_INSTITUCION", socio2);
        assertEquals(1, historial.json().path("items").size(),
                "El historial conserva la cancelacion institucional");
    }
}
