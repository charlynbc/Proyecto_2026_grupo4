package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-10 y la devolucion de pases de RF-24 contra PostgreSQL real. */
class CancelacionConsultaIT extends BaseIntegracionIT {

    private static final int RONDAS = 6;

    private Respuesta reservar(String token, long numeroId, Long paseId) {
        return post("/api/consultas", token, paseId == null
                ? "{\"numeroId\":%d}".formatted(numeroId)
                : "{\"numeroId\":%d,\"paseId\":%d}".formatted(numeroId, paseId));
    }

    private Respuesta cancelar(String token, Object consultaId) {
        return post("/api/consultas/" + consultaId + "/cancelar", token, null);
    }

    private long reservarOk(String token, long numeroId, Long paseId) {
        Respuesta r = reservar(token, numeroId, paseId);
        assertEquals(201, r.estado(), r.cuerpo());
        return r.json().path("id").asLong();
    }

    private JsonNode pasesDisponibles(String token) {
        Respuesta r = get("/api/socios/me/pases/disponibles", token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    /** Numero que empieza dentro de los minutos indicados; la fecha es la que corresponda, incluso si cruza la medianoche. */
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

    /** Socio con una consulta ATENDIDA pasada y un pase vigente hacia la especialidad con pase. */
    private long emitirPase(long socio, int diasVigencia) {
        long turnoPasado = sembrarTurno(hoy().minusDays(10), 1);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, estado, resultado_registrado_por,"
                        + " fecha_resultado) VALUES (?, ?, 'ATENDIDA', ?, now()) RETURNING id_consulta",
                Long.class, socio, numeroId(turnoPasado, 1), idMedico);
        long atencion = jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion) VALUES (?, ?, 'Control')"
                        + " RETURNING id_atencion", Long.class, consulta, idMedico);
        return jdbc.queryForObject(
                "INSERT INTO pase (id_atencion, id_especialidad_destino, vence_el)"
                        + " VALUES (?, ?, ?) RETURNING id_pase",
                Long.class, atencion, idEspecialidadConPase, hoy().plusDays(diasVigencia));
    }

    private long numeroConPase(int dias) {
        long turno = sembrarTurno(hoy().plusDays(dias), 2);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ? WHERE id_turno_semanal ="
                + " (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)", idEspecialidadConPase, turno);
        return numeroId(turno, 1);
    }

    @Test
    void cancelacionValidaConservaHistoricoYLiberaElNumero() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(7), 2), 1);
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        long consulta = reservarOk(socio1, numero, null);

        Respuesta r = cancelar(socio1, consulta);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(consulta, r.json().path("consultaId").asLong());
        assertEquals("CANCELADA_SOCIO", r.json().path("estado").asString());
        assertFalse(r.json().path("paseDevuelto").asBoolean());
        assertNotNull(r.json().path("canceladaEn").asString());
        assertEquals("CANCELADA_SOCIO", estadoConsulta(consulta));
        assertEquals(idSocio1, jdbc.queryForObject(
                "SELECT cancelada_por FROM consulta WHERE id_consulta = ?", Long.class, consulta));

        // El histórico conserva la consulta cancelada.
        Respuesta detalle = get("/api/consultas/" + consulta, socio1);
        assertEquals(200, detalle.estado());
        assertEquals("CANCELADA_SOCIO", detalle.json().path("estado").asString());
        assertNotNull(detalle.json().path("canceladaEn").asString());
        assertEquals(1, contar("consulta"));

        // El número vuelve a ofrecerse y otro socio puede reservarlo.
        reservarOk(socio2, numero, null);
        assertEquals(2, contar("consulta"));
        assertEquals("AGENDADA", jdbc.queryForObject(
                "SELECT estado FROM consulta WHERE id_numero = ? AND id_socio = ?",
                String.class, numero, idSocio2));
    }

    @Test
    void elSocioQuePerdioElNumeroPuedeReservarlodeNuevoLuegoDeCancelar() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(7), 1), 1);
        String socio = tokenSocio(ciSocio1);

        long primera = reservarOk(socio, numero, null);
        assertEquals(200, cancelar(socio, primera).estado());
        long segunda = reservarOk(socio, numero, null);

        assertTrue(segunda > primera);
        assertEquals("CANCELADA_SOCIO", estadoConsulta(primera));
        assertEquals("AGENDADA", estadoConsulta(segunda));
    }

    @Test
    void consultaAjenaEInexistenteDevuelven404SinCambiarNada() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(7), 1), 1);
        long consulta = reservarOk(tokenSocio(ciSocio1), numero, null);
        String intruso = tokenSocio(ciSocio2);

        Respuesta ajena = cancelar(intruso, consulta);
        Respuesta inexistente = cancelar(intruso, 987654);

        assertEquals(404, ajena.estado());
        assertEquals("NO_ENCONTRADO", ajena.codigo());
        assertEquals(404, inexistente.estado());
        assertEquals(inexistente.json().path("message").asString(), ajena.json().path("message").asString());
        assertFalse(ajena.cuerpo().contains("Socia"), "No debe filtrar datos de la consulta ajena");
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void identificadorInvalidoDevuelve400() {
        String socio = tokenSocio(ciSocio1);

        for (String id : List.of("abc", "0", "-5")) {
            Respuesta r = cancelar(socio, id);
            assertEquals(400, r.estado(), id + " " + r.cuerpo());
            assertEquals("VALIDACION", r.codigo());
        }
    }

    @Test
    void consultaYaCanceladaOAtendidaDevuelve409() {
        long turno = sembrarTurno(hoy().plusDays(7), 3);
        String socio = tokenSocio(ciSocio1);
        long cancelada = reservarOk(socio, numeroId(turno, 1), null);
        assertEquals(200, cancelar(socio, cancelada).estado());
        long atendida = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, estado, resultado_registrado_por,"
                        + " fecha_resultado) VALUES (?, ?, 'ATENDIDA', ?, now()) RETURNING id_consulta",
                Long.class, idSocio1, numeroId(turno, 2), idMedico);

        Respuesta segunda = cancelar(socio, cancelada);
        Respuesta sobreAtendida = cancelar(socio, atendida);

        assertEquals(409, segunda.estado());
        assertEquals("CONSULTA_NO_AGENDADA", segunda.codigo());
        assertEquals(409, sobreAtendida.estado());
        assertEquals("CONSULTA_NO_AGENDADA", sobreAtendida.codigo());
        assertEquals("ATENDIDA", estadoConsulta(atendida));
    }

    @Test
    void conAvisoDeLlegadaNoSePuedeCancelar() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(7), 1), 1);
        String socio = tokenSocio(ciSocio1);
        long consulta = reservarOk(socio, numero, null);
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)",
                idSocio1, idFuncionario, hoy().plusDays(7));

        Respuesta r = cancelar(socio, consulta);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("LLEGADA_YA_REGISTRADA", r.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void avisoDeOtroDiaNoImpideCancelar() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(7), 1), 1);
        String socio = tokenSocio(ciSocio1);
        long consulta = reservarOk(socio, numero, null);
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)",
                idSocio1, idFuncionario, hoy().plusDays(6));

        assertEquals(200, cancelar(socio, consulta).estado());
    }

    @Test
    void menosDeDosHorasDeAnticipacionDevuelve409YMasDeDosHorasPermite() {
        String socio = tokenSocio(ciSocio1);
        long cercano = numeroHoyEnMinutos(60);
        long consultaCercana = sembrarConsulta(idSocio1, cercano);

        Respuesta tarde = cancelar(socio, consultaCercana);

        assertEquals(409, tarde.estado(), tarde.cuerpo());
        assertEquals("CANCELACION_FUERA_DE_PLAZO", tarde.codigo());
        assertEquals("AGENDADA", estadoConsulta(consultaCercana));
    }

    @Test
    void consultaConMasDeDosHorasDeAnticipacionElMismoDiaSePuedeCancelar() {
        String socio = tokenSocio(ciSocio1);
        long lejano = numeroHoyEnMinutos(150);
        long consulta = sembrarConsulta(idSocio1, lejano);

        Respuesta r = cancelar(socio, consulta);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("CANCELADA_SOCIO", estadoConsulta(consulta));
    }

    @Test
    void consultaDeUnDiaPasadoNoSePuedeCancelar() {
        long numero = numeroId(sembrarTurno(hoy().minusDays(1), 1), 1);
        long consulta = sembrarConsulta(idSocio1, numero);

        Respuesta r = cancelar(tokenSocio(ciSocio1), consulta);

        assertEquals(409, r.estado());
        assertEquals("CANCELACION_FUERA_DE_PLAZO", r.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void rolesDistintosDeSocioYSinTokenSonRechazados() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(7), 1), 1);
        long consulta = reservarOk(tokenSocio(ciSocio1), numero, null);

        assertEquals(401, cancelar(null, consulta).estado());
        assertEquals(403, cancelar(tokenEmpleado(ciFuncionario), consulta).estado());
        assertEquals(403, cancelar(tokenEmpleado(ciMedico), consulta).estado());
        assertEquals(403, cancelar(tokenEmpleado(ciAdmin), consulta).estado());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void elPaseVuelveADisponibleConSuVencimientoOriginalTrasCancelar() {
        long pase = emitirPase(idSocio1, 30);
        String socio = tokenSocio(ciSocio1);
        long numero = numeroConPase(7);
        LocalDate vencimiento = hoy().plusDays(30);

        JsonNode antes = pasesDisponibles(socio);
        assertEquals(1, antes.size());
        assertEquals(vencimiento.toString(), antes.get(0).path("venceEl").asString());

        long consulta = reservarOk(socio, numero, pase);
        assertEquals(0, pasesDisponibles(socio).size(), "El pase queda consumido por la reserva");

        Respuesta r = cancelar(socio, consulta);
        assertEquals(200, r.estado(), r.cuerpo());
        assertTrue(r.json().path("paseDevuelto").asBoolean());

        JsonNode despues = pasesDisponibles(socio);
        assertEquals(1, despues.size());
        assertEquals(pase, despues.get(0).path("id").asLong());
        assertEquals(vencimiento.toString(), despues.get(0).path("venceEl").asString());
        assertEquals(1, contar("pase"), "Cancelar no crea ni borra pases");
        assertEquals(pase, jdbc.queryForObject(
                "SELECT id_pase FROM consulta WHERE id_consulta = ?", Long.class, consulta),
                "La consulta cancelada conserva el pase usado");
    }

    @Test
    void ciclosRepetidosDeReservaYCancelacionNuncaDuplicanElPase() {
        long pase = emitirPase(idSocio1, 30);
        String socio = tokenSocio(ciSocio1);
        long numero = numeroConPase(7);

        for (int i = 0; i < RONDAS; i++) {
            long consulta = reservarOk(socio, numero, pase);
            assertEquals(0, pasesDisponibles(socio).size(), "Ronda " + i);
            assertEquals(200, cancelar(socio, consulta).estado());
            assertEquals(1, pasesDisponibles(socio).size(), "Ronda " + i);
        }
        assertEquals(1, contar("pase"));
        assertEquals(RONDAS, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_pase = ? AND estado = 'CANCELADA_SOCIO'",
                Integer.class, pase));
    }

    @Test
    void paseVencidoNoVuelveADisponible() {
        long pase = emitirPase(idSocio1, 30);
        String socio = tokenSocio(ciSocio1);
        long numero = numeroConPase(7);
        long consulta = reservarOk(socio, numero, pase);
        // Simula el paso del tiempo: el pase se emitió hace 40 días y venció ayer.
        jdbc.update("UPDATE pase SET emitido_en = now() - interval '40 days', vence_el = ? WHERE id_pase = ?",
                hoy().minusDays(1), pase);

        Respuesta r = cancelar(socio, consulta);

        assertEquals(200, r.estado(), r.cuerpo());
        assertFalse(r.json().path("paseDevuelto").asBoolean());
        assertEquals(0, pasesDisponibles(socio).size());
    }

    @Test
    void laInasistenciaNoDevuelveElPase() {
        long pase = emitirPase(idSocio1, 30);
        String socio = tokenSocio(ciSocio1);
        long turnoPasado = sembrarTurno(hoy().minusDays(2), 1);
        jdbc.update("INSERT INTO consulta (id_socio, id_numero, id_pase) VALUES (?, ?, ?)",
                idSocio1, numeroId(turnoPasado, 1), pase);

        // Consulta agendada que ya pasó sin aviso: NO_ASISTIO derivado, sigue usando el pase.
        assertEquals(0, pasesDisponibles(socio).size());
    }

    @Test
    void doblesCancelacionesSimultaneasSoloAplicanUna() throws Exception {
        long pase = emitirPase(idSocio1, 30);
        String socio = tokenSocio(ciSocio1);
        long numero = numeroConPase(7);

        for (int ronda = 0; ronda < RONDAS; ronda++) {
            long consulta = reservarOk(socio, numero, pase);
            List<Respuesta> r = enParalelo(List.of(
                    () -> cancelar(socio, consulta),
                    () -> cancelar(socio, consulta)));

            assertEquals(1, r.stream().filter(x -> x.estado() == 200).count(), "Ronda " + ronda + r);
            assertEquals(1, r.stream().filter(x -> x.estado() == 409).count(), "Ronda " + ronda + r);
            assertEquals("CONSULTA_NO_AGENDADA", r.stream().filter(x -> x.estado() == 409)
                    .findFirst().orElseThrow().codigo());
            assertEquals(1, pasesDisponibles(socio).size(), "El pase se devuelve una sola vez");
        }
    }

    @Test
    void cancelacionYReservaSimultaneasNuncaOcupanElNumeroDosVeces() throws Exception {
        long numero = numeroId(sembrarTurno(hoy().plusDays(7), 1), 1);
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);

        for (int ronda = 0; ronda < RONDAS; ronda++) {
            jdbc.update("DELETE FROM notificacion");
            jdbc.update("DELETE FROM consulta");
            long consulta = reservarOk(socio1, numero, null);

            List<Respuesta> r = enParalelo(List.of(
                    () -> cancelar(socio1, consulta),
                    () -> reservar(socio2, numero, null)));

            for (Respuesta x : r) {
                assertTrue(x.estado() < 500, "Error de servidor: " + x.estado() + " " + x.cuerpo());
            }
            assertEquals(200, r.get(0).estado(), r.get(0).cuerpo());
            assertTrue(r.get(1).estado() == 201 || r.get(1).estado() == 409, r.get(1).cuerpo());
            int ocupadas = jdbc.queryForObject(
                    "SELECT count(*) FROM consulta WHERE id_numero = ? AND estado = 'AGENDADA'",
                    Integer.class, numero);
            assertEquals(r.get(1).estado() == 201 ? 1 : 0, ocupadas, "Ronda " + ronda);
            assertEquals("CANCELADA_SOCIO", estadoConsulta(consulta));
        }
    }

    @Test
    void laCancelacionNoModificaOtrasConsultasNiElEstadoDelNumeroVecino() {
        long turno = sembrarTurno(hoy().plusDays(7), 2);
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        long a = reservarOk(socio1, numeroId(turno, 1), null);
        long b = reservarOk(socio2, numeroId(turno, 2), null);

        assertEquals(200, cancelar(socio1, a).estado());

        assertEquals("AGENDADA", estadoConsulta(b));
        assertNull(jdbc.queryForObject(
                "SELECT cancelada_en FROM consulta WHERE id_consulta = ?", Object.class, b));
    }

    private List<Respuesta> enParalelo(List<Callable<Respuesta>> tareas) throws Exception {
        CyclicBarrier barrera = new CyclicBarrier(tareas.size());
        ExecutorService pool = Executors.newFixedThreadPool(tareas.size());
        try {
            List<Future<Respuesta>> futuros = new ArrayList<>();
            for (Callable<Respuesta> tarea : tareas) {
                futuros.add(pool.submit(() -> {
                    barrera.await(20, TimeUnit.SECONDS);
                    return tarea.call();
                }));
            }
            List<Respuesta> resultados = new ArrayList<>();
            for (Future<Respuesta> futuro : futuros) {
                resultados.add(futuro.get(60, TimeUnit.SECONDS));
            }
            return resultados;
        } finally {
            pool.shutdownNow();
        }
    }
}
