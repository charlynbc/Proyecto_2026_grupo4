package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.junit.jupiter.api.Test;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.notificacion.PushSender;

/**
 * El aviso de suspension (RF-14) contra PostgreSQL real: un aviso por consulta,
 * cada uno con su propia fecha, horario, numero, especialidad y medico, y el mismo
 * contenido en la notificacion, el correo y el push.
 *
 * Los ids de turno, consulta, numero, especialidad y medico se siembran sin
 * coincidir entre si (se adelantan las secuencias), y hay una consulta de otro
 * medico y otra especialidad que no se suspende: un JOIN mal escrito no puede
 * pasar por casualidad.
 */
class SuspensionAvisosIT extends BaseIntegracionIT {

    @MockitoBean
    CorreoSender correoSender;

    @MockitoBean
    PushSender pushSender;

    private long medicoOtro;
    private long especialidadOtra;
    private long turnoA;
    private long turnoB;
    private long turnoOtro;
    private long consultaA;
    private long consultaB;
    private long consultaOtra;
    private long numeroA;
    private long numeroB;

    private final LocalDate fechaA = hoy().plusDays(7);
    private final LocalDate fechaB = hoy().plusDays(9);
    private final LocalDate fechaOtra = hoy().plusDays(8);

    private static String dia(LocalDate fecha) {
        return "%02d/%02d/%d".formatted(fecha.getDayOfMonth(), fecha.getMonthValue(), fecha.getYear());
    }

    private String correoDe(String ci) {
        return "u" + ci + "@ejemplo.invalid";
    }

    private void adelantarSecuencia(String tabla, String columna, long valor) {
        jdbc.queryForObject("SELECT setval(pg_get_serial_sequence(?, ?)::regclass, ?)",
                Long.class, tabla, columna, valor);
    }

    /** Turno de una fecha con tres numeros de 20 minutos desde las 10:00, de ese medico y especialidad. */
    private long sembrarTurnoDe(long medico, long especialidad, LocalDate fecha) {
        long semanal = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, medico, especialidad, idConsultorio, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha) VALUES (?, ?, ?)"
                        + " RETURNING id_turno", Long.class, semanal, idConsultorio, fecha);
        for (int i = 0; i < 3; i++) {
            int inicio = 10 * 60 + i * 20;
            long patron = jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, semanal, i + 1, hora(inicio), hora(inicio + 20));
            jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                    + " VALUES (?, ?, ?, ?::time, ?::time)",
                    turno, patron, i + 1, hora(inicio), hora(inicio + 20));
        }
        return turno;
    }

    private void sembrarSuspension() {
        // El medico de la suspension lleva tilde y enie para ver que el texto las conserva.
        jdbc.update("UPDATE persona SET nombre = 'Martín', apellido = 'Núñez' WHERE ci = ?", ciMedico);

        especialidadOtra = jdbc.queryForObject(
                "INSERT INTO especialidad (nombre, requiere_pase) VALUES ('Pediatria', false)"
                        + " RETURNING id_especialidad", Long.class);
        medicoOtro = cuenta(ci(1000010), "Lucía", "Pérez", "MEDICO", true);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", medicoOtro, especialidadOtra);

        // Cada secuencia arranca en un rango propio: ningun id coincide con otro.
        adelantarSecuencia("turno_semanal", "id_turno_semanal", 150);
        adelantarSecuencia("numero_semanal", "id_numero_semanal", 250);
        adelantarSecuencia("turno", "id_turno", 40);
        adelantarSecuencia("numero", "id_numero", 90);
        adelantarSecuencia("consulta", "id_consulta", 70);

        turnoA = sembrarTurnoDe(idMedico, idEspecialidad, fechaA);
        turnoOtro = sembrarTurnoDe(medicoOtro, especialidadOtra, fechaOtra);
        turnoB = sembrarTurnoDe(idMedico, idEspecialidad, fechaB);
        numeroA = numeroId(turnoA, 2);
        numeroB = numeroId(turnoB, 3);
        // Dos consultas del mismo socio, de distinta fecha y numero, y la de otro socio con otro medico.
        consultaA = sembrarConsulta(idSocio1, numeroA);
        consultaOtra = sembrarConsulta(idSocio2, numeroId(turnoOtro, 1));
        consultaB = sembrarConsulta(idSocio1, numeroB);

        Set<Long> ids = new HashSet<>(List.of(
                turnoA, turnoB, turnoOtro, consultaA, consultaB, consultaOtra,
                numeroA, numeroB, idEspecialidad, especialidadOtra, idMedico, medicoOtro));
        assertEquals(12, ids.size(), "Los ids sembrados no pueden coincidir entre si: " + ids);
    }

    private Respuesta suspender(String observacion, long... turnos) {
        String ids = String.join(",", java.util.Arrays.stream(turnos)
                .mapToObj(Long::toString).toList());
        String obs = observacion == null ? "null" : "\"" + observacion + "\"";
        return post("/api/turnos/suspensiones", tokenEmpleado(ciFuncionario), """
                {"filtro":{"medicoId":%d,"especialidadId":%d,"fechaDesde":"%s","fechaHasta":"%s"},
                 "ids":[%s],"observacion":%s,"cantidadConfirmada":%d}
                """.formatted(idMedico, idEspecialidad, hoy().plusDays(6), hoy().plusDays(10),
                ids, obs, turnos.length == 2 ? 2 : 1));
    }

    private String contenido(long consulta) {
        return jdbc.queryForObject(
                "SELECT contenido FROM notificacion WHERE id_consulta = ? AND tipo = 'SUSPENSION'",
                String.class, consulta);
    }

    private long notificacion(long consulta) {
        return jdbc.queryForObject(
                "SELECT id_notificacion FROM notificacion WHERE id_consulta = ? AND tipo = 'SUSPENSION'",
                Long.class, consulta);
    }

    @Test
    void suspenderDosFechasCreaUnAvisoPorConsultaConSuPropioContenidoEnLosTresCanales() {
        sembrarSuspension();
        jdbc.update("INSERT INTO dispositivo_push (id_socio, token) VALUES (?, ?)",
                idSocio1, "token-a");

        Respuesta r = suspender("Congreso de la especialidad", turnoA, turnoB);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE tipo = 'SUSPENSION'", Integer.class));
        String cuerpoA = "Tu consulta de Medicina General con Martín Núñez del " + dia(fechaA)
                + " fue cancelada por la institución. Horario: 10:20 a 10:40 (número 2)."
                + " Motivo: Congreso de la especialidad";
        String cuerpoB = "Tu consulta de Medicina General con Martín Núñez del " + dia(fechaB)
                + " fue cancelada por la institución. Horario: 10:40 a 11:00 (número 3)."
                + " Motivo: Congreso de la especialidad";
        assertEquals(cuerpoA, contenido(consultaA));
        assertEquals(cuerpoB, contenido(consultaB));

        // El mismo contenido llega por correo y por push, con el titulo del tipo.
        verify(correoSender).enviar(new CorreoMensaje(correoDe(ciSocio1), "Turno suspendido", cuerpoA));
        verify(correoSender).enviar(new CorreoMensaje(correoDe(ciSocio1), "Turno suspendido", cuerpoB));
        verify(pushSender).enviar(eq("token-a"), eq("Turno suspendido"), eq(cuerpoA),
                eq(Map.of("tipo", "SUSPENSION", "notificacionId", String.valueOf(notificacion(consultaA)))));
        verify(pushSender).enviar(eq("token-a"), eq("Turno suspendido"), eq(cuerpoB),
                eq(Map.of("tipo", "SUSPENSION", "notificacionId", String.valueOf(notificacion(consultaB)))));

        // La consulta de otro medico y otra especialidad no se toca ni recibe aviso.
        assertEquals("AGENDADA", estadoConsulta(consultaOtra));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE id_consulta = ?", Integer.class, consultaOtra));
        verify(correoSender, times(2)).enviar(any());
    }

    @Test
    void sinObservacionElAvisoDeSuspensionNoLlevaLaOracionDelMotivo() {
        sembrarSuspension();

        Respuesta r = suspender(null, turnoA);

        assertEquals(200, r.estado(), r.cuerpo());
        String cuerpo = contenido(consultaA);
        assertEquals("Tu consulta de Medicina General con Martín Núñez del " + dia(fechaA)
                + " fue cancelada por la institución. Horario: 10:20 a 10:40 (número 2).", cuerpo);
        assertFalse(cuerpo.contains("Motivo"), cuerpo);
        assertEquals("AGENDADA", estadoConsulta(consultaB));
    }
}
