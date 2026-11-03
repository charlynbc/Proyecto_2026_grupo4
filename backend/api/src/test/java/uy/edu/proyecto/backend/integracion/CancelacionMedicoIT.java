package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;

/** RF-27: cancelación individual y masiva por el médico contra PostgreSQL real. */
class CancelacionMedicoIT extends BaseIntegracionIT {

    private String tokenMedico() {
        return tokenEmpleado(ciMedico);
    }

    private Respuesta cancelarConsulta(String token, Object consultaId, String cuerpo) {
        return post("/api/medico/consultas/" + consultaId + "/cancelar", token, cuerpo);
    }

    private Respuesta cancelarTurno(String token, Object turnoId, String cuerpo) {
        return post("/api/medico/turnos/" + turnoId + "/cancelar", token, cuerpo);
    }

    private long reservar(String tokenSocio, long numero) {
        Respuesta r = post("/api/consultas", tokenSocio,
                "{\"numeroId\":%d}".formatted(numero));
        assertEquals(201, r.estado(), r.cuerpo());
        return r.json().path("id").asLong();
    }

    /** Número de hoy que empieza dentro de los minutos indicados (redondeado a 5). */
    private long numeroHoyEnMinutos(int minutosDesdeAhora) {
        LocalDateTime objetivo = LocalDateTime.now(ZONA).plusMinutes(minutosDesdeAhora)
                .withSecond(0).withNano(0);
        if (objetivo.getHour() == 23 && objetivo.getMinute() >= 40) {
            objetivo = objetivo.plusMinutes(30);
        }
        LocalTime inicio = objetivo.toLocalTime().minusMinutes(objetivo.getMinute() % 5);
        objetivo = objetivo.minusMinutes(objetivo.getMinute() % 5);
        long turno = sembrarTurno(objetivo.toLocalDate(), 0);
        long semanal = jdbc.queryForObject(
                "SELECT id_turno_semanal FROM turno WHERE id_turno = ?", Long.class, turno);
        long patron = jdbc.queryForObject(
                "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                        + " VALUES (?, 1, ?::time, ?::time) RETURNING id_numero_semanal",
                Long.class, semanal, inicio.toString(), inicio.plusMinutes(20).toString());
        return jdbc.queryForObject(
                "INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                        + " VALUES (?, ?, 1, ?::time, ?::time) RETURNING id_numero",
                Long.class, turno, patron, inicio.toString(), inicio.plusMinutes(20).toString());
    }

    /** Pase vigente del socio hacia la especialidad con pase, emitido por el médico. */
    private long emitirPase(long socio, int diasVigencia) {
        long turnoPasado = sembrarTurno(hoy().minusDays(10), 1);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, estado, resultado_registrado_por,"
                        + " fecha_resultado) VALUES (?, ?, 'ATENDIDA', ?, now())"
                        + " RETURNING id_consulta",
                Long.class, socio, numeroId(turnoPasado, 1), idMedico);
        long atencion = jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion) VALUES (?, ?, 'Control')"
                        + " RETURNING id_atencion", Long.class, consulta, idMedico);
        return jdbc.queryForObject(
                "INSERT INTO pase (id_atencion, id_especialidad_destino, vence_el)"
                        + " VALUES (?, ?, ?) RETURNING id_pase",
                Long.class, atencion, idEspecialidadConPase, hoy().plusDays(diasVigencia));
    }

    /** Turno de la especialidad con pase (Medicina General pasa a Cardiologia). */
    private long turnoConPase(LocalDate fecha, int numeros) {
        long turno = sembrarTurno(fecha, numeros);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ? WHERE id_turno_semanal ="
                + " (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)",
                idEspecialidadConPase, turno);
        return turno;
    }

    /** Cuenta SOCIO con la misma CI del médico (conflicto de interés de 3.1.5). */
    private long socioDelPropioMedico() {
        return jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'SOCIO', ?, '099111222',"
                        + " 'Calle Falsa 123', 'x', TRUE) RETURNING id_cuenta",
                Long.class, ciMedico, "medico.socio@ejemplo.invalid");
    }

    private long otroMedicoConTurno(LocalDate fecha, int numeros) {
        String ci = ci(1000099);
        jdbc.update("INSERT INTO persona VALUES (?, 'Otto', 'Medico', DATE '1980-01-01')", ci);
        long otro = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'MEDICO', ?, '099111222',"
                        + " 'Calle Falsa 123', 'x', TRUE) RETURNING id_cuenta",
                Long.class, ci, "otto@ejemplo.invalid");
        long semanal = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, otro, idEspecialidad, idConsultorio, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha) VALUES (?, ?, ?)"
                        + " RETURNING id_turno", Long.class, semanal, idConsultorio, fecha);
        for (int i = 0; i < numeros; i++) {
            int inicio = 15 * 60 + i * 20;
            long patron = jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, semanal, i + 1, hora(inicio), hora(inicio + 20));
            jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio,"
                    + " hora_fin) VALUES (?, ?, ?, ?::time, ?::time)",
                    turno, patron, i + 1, hora(inicio), hora(inicio + 20));
        }
        return turno;
    }

    /* ---------- Cancelación individual ---------- */

    @Test
    void cancelacionIndividualCorrectaRegistraMotivoYLiberaElNumero() {
        long turno = sembrarTurno(hoy().plusDays(7), 2);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));

        Respuesta r = cancelarConsulta(tokenMedico(), consulta, "{\"motivo\":\"Imprevisto\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(consulta, r.json().path("consultaId").asLong());
        assertEquals("CANCELADA_INSTITUCION", r.json().path("estado").asString());
        assertFalse(r.json().path("paseDevuelto").asBoolean());
        assertNotNull(r.json().path("canceladaEn").asString());

        assertEquals("CANCELADA_INSTITUCION", estadoConsulta(consulta));
        assertEquals(idMedico, jdbc.queryForObject(
                "SELECT cancelada_por FROM consulta WHERE id_consulta = ?", Long.class, consulta));
        assertEquals("Imprevisto", jdbc.queryForObject(
                "SELECT motivo_cancelacion FROM consulta WHERE id_consulta = ?",
                String.class, consulta));
        assertNullEventoSuspension(consulta);

        // Notificación con el motivo y su envío por correo quedan registrados.
        String contenido = jdbc.queryForObject(
                "SELECT n.contenido FROM notificacion n WHERE n.id_consulta = ?"
                        + " AND n.tipo = 'CANCELACION'", String.class, consulta);
        assertNotNull(contenido);
        assertTrue(contenido.contains("Imprevisto"), contenido);
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM envio_notificacion e JOIN notificacion n"
                        + " ON n.id_notificacion = e.id_notificacion"
                        + " WHERE n.id_consulta = ? AND e.canal = 'CORREO'",
                Integer.class, consulta));

        // El número vuelve a estar disponible: otro socio puede agendarlo.
        long nueva = reservar(tokenSocio(ciSocio2), numeroId(turno, 1));
        assertEquals("AGENDADA", estadoConsulta(nueva));
    }

    @Test
    void motivoVacioOAusenteDevuelve400() {
        long turno = sembrarTurno(hoy().plusDays(7), 1);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));
        String medico = tokenMedico();

        assertEquals(400, cancelarConsulta(medico, consulta, "{\"motivo\":\"  \"}").estado());
        assertEquals(400, cancelarConsulta(medico, consulta, "{}").estado());
        assertEquals(400, cancelarConsulta(medico, consulta, null).estado());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void consultaDeOtroMedicoDevuelve404() {
        long turnoAjeno = otroMedicoConTurno(hoy().plusDays(7), 1);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turnoAjeno, 1));

        Respuesta r = cancelarConsulta(tokenMedico(), consulta, "{\"motivo\":\"x\"}");

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("NO_ENCONTRADO", r.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void consultaYaCanceladaDevuelve409() {
        long turno = sembrarTurno(hoy().plusDays(7), 1);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));
        String medico = tokenMedico();
        assertEquals(200, cancelarConsulta(medico, consulta, "{\"motivo\":\"x\"}").estado());

        Respuesta r = cancelarConsulta(medico, consulta, "{\"motivo\":\"x\"}");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("CONSULTA_NO_AGENDADA", r.codigo());
    }

    @Test
    void menosDeDosHorasDevuelve409() {
        // La agenda exige 2 h de anticipación, así que la consulta cercana se siembra directo.
        long numero = numeroHoyEnMinutos(60);
        long consulta = sembrarConsulta(idSocio1, numero);

        Respuesta r = cancelarConsulta(tokenMedico(), consulta, "{\"motivo\":\"x\"}");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("CANCELACION_FUERA_DE_PLAZO", r.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void conflictoDeInteresDevuelve403() {
        long socioPropio = socioDelPropioMedico();
        long turno = sembrarTurno(hoy().plusDays(7), 1);
        long consulta = sembrarConsulta(socioPropio, numeroId(turno, 1));

        Respuesta r = cancelarConsulta(tokenMedico(), consulta, "{\"motivo\":\"x\"}");

        assertEquals(403, r.estado(), r.cuerpo());
        assertEquals("CONFLICTO_DE_INTERES", r.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void paseVigenteSeDevuelveYPaseVencidoNo() {
        // Pase vigente: vuelve a estar disponible tras la cancelación.
        long pase = emitirPase(idSocio1, 30);
        long turno = turnoConPase(hoy().plusDays(7), 1);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, id_pase) VALUES (?, ?, ?)"
                        + " RETURNING id_consulta",
                Long.class, idSocio1, numeroId(turno, 1), pase);

        Respuesta r = cancelarConsulta(tokenMedico(), consulta, "{\"motivo\":\"x\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertTrue(r.json().path("paseDevuelto").asBoolean());
        Respuesta disponibles = get("/api/socios/me/pases/disponibles", tokenSocio(ciSocio1));
        assertEquals(200, disponibles.estado(), disponibles.cuerpo());
        assertTrue(disponibles.cuerpo().contains("\"id\":" + pase), disponibles.cuerpo());

        // Pase vencido: la cancelación no lo rehabilita.
        long paseVencido = emitirPase(idSocio2, 1);
        jdbc.update("UPDATE pase SET emitido_en = now() - interval '10 days',"
                + " vence_el = ? WHERE id_pase = ?", hoy().minusDays(1), paseVencido);
        long turno2 = turnoConPase(hoy().plusDays(8), 1);
        long consulta2 = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, id_pase) VALUES (?, ?, ?)"
                        + " RETURNING id_consulta",
                Long.class, idSocio2, numeroId(turno2, 1), paseVencido);

        Respuesta r2 = cancelarConsulta(tokenMedico(), consulta2, "{\"motivo\":\"x\"}");

        assertEquals(200, r2.estado(), r2.cuerpo());
        assertFalse(r2.json().path("paseDevuelto").asBoolean());
        Respuesta disponibles2 = get("/api/socios/me/pases/disponibles", tokenSocio(ciSocio2));
        assertFalse(disponibles2.cuerpo().contains("\"id\":" + paseVencido),
                disponibles2.cuerpo());
    }

    @Test
    void cancelacionesConcurrentesSoloUnaTieneExito() throws Exception {
        long turno = sembrarTurno(hoy().plusDays(7), 1);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));
        String medico = tokenMedico();
        CyclicBarrier barrera = new CyclicBarrier(2);
        Callable<Integer> tarea = () -> {
            barrera.await(10, TimeUnit.SECONDS);
            return cancelarConsulta(medico, consulta, "{\"motivo\":\"x\"}").estado();
        };
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<Integer> a = pool.submit(tarea);
            Future<Integer> b = pool.submit(tarea);
            List<Integer> estados = List.of(a.get(30, TimeUnit.SECONDS),
                    b.get(30, TimeUnit.SECONDS));
            assertTrue(estados.contains(200), estados.toString());
            assertTrue(estados.contains(409), estados.toString());
        } finally {
            pool.shutdownNow();
        }
        assertEquals("CANCELADA_INSTITUCION", estadoConsulta(consulta));
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE id_consulta = ?"
                        + " AND tipo = 'CANCELACION'",
                Integer.class, consulta));
    }

    /* ---------- Cancelación masiva (turno de una fecha) ---------- */

    @Test
    void cancelacionMasivaSuspendeLaFechaYNotificaConMotivo() {
        long turno = sembrarTurno(hoy().plusDays(7), 3);
        long c1 = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));
        long c2 = reservar(tokenSocio(ciSocio2), numeroId(turno, 2));

        Respuesta r = cancelarTurno(tokenMedico(), turno, "{\"motivo\":\"Guardia\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(turno, r.json().path("turnoId").asLong());
        assertEquals("SUSPENDIDO", r.json().path("estado").asString());
        assertEquals(2, r.json().path("consultasCanceladas").asInt());

        assertEquals("SUSPENDIDO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?", String.class, turno));
        for (long c : List.of(c1, c2)) {
            assertEquals("CANCELADA_INSTITUCION", estadoConsulta(c));
            assertEquals(idMedico, jdbc.queryForObject(
                    "SELECT cancelada_por FROM consulta WHERE id_consulta = ?",
                    Long.class, c));
            assertEquals("Guardia", jdbc.queryForObject(
                    "SELECT motivo_cancelacion FROM consulta WHERE id_consulta = ?",
                    String.class, c));
            assertNotNull(jdbc.queryForObject(
                    "SELECT id_evento_suspension FROM consulta WHERE id_consulta = ?",
                    Long.class, c));
            String contenido = jdbc.queryForObject(
                    "SELECT contenido FROM notificacion WHERE id_consulta = ?"
                            + " AND tipo = 'SUSPENSION'", String.class, c);
            assertTrue(contenido.contains("Guardia"), contenido);
        }
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM turno_evento WHERE id_turno = ? AND tipo = 'SUSPENSION'"
                        + " AND id_responsable = ? AND observacion = 'Guardia'",
                Integer.class, turno, idMedico));

        // La fecha suspendida no ofrece números: ya no se puede agendar en ella.
        Respuesta tarde = post("/api/consultas", tokenSocio(ciSocio3),
                "{\"numeroId\":%d}".formatted(numeroId(turno, 3)));
        assertEquals(409, tarde.estado(), tarde.cuerpo());
    }

    @Test
    void cancelacionMasivaSinConsultasSuspendeLaFecha() {
        long turno = sembrarTurno(hoy().plusDays(7), 2);

        Respuesta r = cancelarTurno(tokenMedico(), turno, "{\"motivo\":\"Guardia\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("consultasCanceladas").asInt());
        assertEquals("SUSPENDIDO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?", String.class, turno));
    }

    @Test
    void turnoDeOtroMedicoDevuelve404() {
        long turnoAjeno = otroMedicoConTurno(hoy().plusDays(7), 1);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turnoAjeno, 1));

        Respuesta r = cancelarTurno(tokenMedico(), turnoAjeno, "{\"motivo\":\"x\"}");

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("ACTIVO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?", String.class, turnoAjeno));
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void unaConsultaFueraDePlazoRechazaTodaLaOperacion() {
        // Los dos números deben quedar en la misma fecha y nunca cruzar medianoche.
        // De noche ya no hay espacio para combinar un número cercano y otro a más
        // de dos horas en el mismo día: usamos dos números vencidos para verificar
        // igualmente que la cancelación masiva se rechaza sin modificar datos.
        LocalDateTime ahora = LocalDateTime.now(ZONA);
        LocalTime inicioCercano;
        LocalTime inicioLejano;
        if (ahora.toLocalTime().isAfter(LocalTime.of(20, 59))) {
            inicioCercano = LocalTime.of(10, 0);
            inicioLejano = LocalTime.of(13, 0);
        } else {
            LocalDateTime base = ahora.plusMinutes(60).withSecond(0).withNano(0);
            inicioCercano = base.toLocalTime().minusMinutes(base.getMinute() % 5);
            inicioLejano = inicioCercano.plusMinutes(150);
        }
        long turno = sembrarTurno(hoy(), 0);
        long semanal = jdbc.queryForObject(
                "SELECT id_turno_semanal FROM turno WHERE id_turno = ?", Long.class, turno);
        for (int i = 0; i < 2; i++) {
            LocalTime inicio = i == 0 ? inicioCercano : inicioLejano;
            long patron = jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, semanal, i + 1, inicio.toString(),
                    inicio.plusMinutes(20).toString());
            jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio,"
                    + " hora_fin) VALUES (?, ?, ?, ?::time, ?::time)",
                    turno, patron, i + 1, inicio.toString(), inicio.plusMinutes(20).toString());
        }
        long c1 = sembrarConsulta(idSocio1, numeroId(turno, 1));
        long c2 = sembrarConsulta(idSocio2, numeroId(turno, 2));

        Respuesta r = cancelarTurno(tokenMedico(), turno, "{\"motivo\":\"Guardia\"}");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("CANCELACION_FUERA_DE_PLAZO", r.codigo());
        // No se modificó ningún dato.
        assertEquals("ACTIVO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?", String.class, turno));
        assertEquals("AGENDADA", estadoConsulta(c1));
        assertEquals("AGENDADA", estadoConsulta(c2));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM turno_evento WHERE id_turno = ?", Integer.class, turno));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE id_consulta IN (?, ?)",
                Integer.class, c1, c2));
    }

    @Test
    void suspensionDeUnaSolaFechaNoAfectaLasDemas() {
        // Dos fechas del mismo médico; se cancela una y la otra sigue activa.
        long turnoA = sembrarTurno(hoy().plusDays(7), 1);
        long turnoB = sembrarTurno(hoy().plusDays(8), 1);
        long consultaB = reservar(tokenSocio(ciSocio2), numeroId(turnoB, 1));
        reservar(tokenSocio(ciSocio1), numeroId(turnoA, 1));

        Respuesta r = cancelarTurno(tokenMedico(), turnoA, "{\"motivo\":\"Guardia\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("ACTIVO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?", String.class, turnoB));
        assertEquals("AGENDADA", estadoConsulta(consultaB));
    }

    @Test
    void rehabilitarLaFechaNoRestauraLasConsultasCanceladas() {
        long turno = sembrarTurno(hoy().plusDays(7), 1);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));
        assertEquals(200, cancelarTurno(tokenMedico(), turno, "{\"motivo\":\"Guardia\"}")
                .estado());

        // El funcionario rehabilita la fecha (RF-15).
        Respuesta rehab = post("/api/turnos/rehabilitaciones", tokenEmpleado(ciFuncionario),
                """
                {"filtro":{"medicoId":%d,"especialidadId":%d,"fechaDesde":"%s","fechaHasta":"%s"},"ids":[%d]}
                """.formatted(idMedico, idEspecialidad,
                        hoy().plusDays(7).toString(), hoy().plusDays(7).toString(), turno));
        assertEquals(200, rehab.estado(), rehab.cuerpo());

        assertEquals("ACTIVO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?", String.class, turno));
        assertEquals("CANCELADA_INSTITUCION", estadoConsulta(consulta));
    }

    @Test
    void conflictoDeInteresEnMasivaRechazaTodaLaOperacion() {
        long socioPropio = socioDelPropioMedico();
        long turno = sembrarTurno(hoy().plusDays(7), 2);
        long c1 = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));
        long c2 = sembrarConsulta(socioPropio, numeroId(turno, 2));

        Respuesta r = cancelarTurno(tokenMedico(), turno, "{\"motivo\":\"Guardia\"}");

        assertEquals(403, r.estado(), r.cuerpo());
        assertEquals("CONFLICTO_DE_INTERES", r.codigo());
        assertEquals("ACTIVO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?", String.class, turno));
        assertEquals("AGENDADA", estadoConsulta(c1));
        assertEquals("AGENDADA", estadoConsulta(c2));
    }

    @Test
    void seguridadSinTokenYRolIncorrecto() {
        long turno = sembrarTurno(hoy().plusDays(7), 1);
        long consulta = reservar(tokenSocio(ciSocio1), numeroId(turno, 1));

        assertEquals(401, cancelarConsulta(null, consulta, "{\"motivo\":\"x\"}").estado());
        assertEquals(401, cancelarTurno(null, turno, "{\"motivo\":\"x\"}").estado());
        assertEquals(403, cancelarConsulta(tokenSocio(ciSocio2), consulta,
                "{\"motivo\":\"x\"}").estado());
        assertEquals(403, cancelarTurno(tokenEmpleado(ciFuncionario), turno,
                "{\"motivo\":\"x\"}").estado());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    private void assertNullEventoSuspension(long consulta) {
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_consulta = ?"
                        + " AND id_evento_suspension IS NOT NULL",
                Integer.class, consulta));
    }
}
