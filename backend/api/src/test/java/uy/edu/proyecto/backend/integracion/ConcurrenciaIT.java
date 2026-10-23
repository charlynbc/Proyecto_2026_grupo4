package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;

/**
 * Concurrencia real: cada hilo usa su propia conexion HTTP/JDBC, se sincroniza con una barrera
 * y toda espera esta acotada. Se verifican invariantes sobre el estado final de PostgreSQL.
 */
class ConcurrenciaIT extends BaseIntegracionIT {

    private static final int RONDAS = 8;

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

    private static long contarEstado(List<Respuesta> respuestas, int estado) {
        return respuestas.stream().filter(r -> r.estado() == estado).count();
    }

    private static void sinErroresDeServidor(List<Respuesta> respuestas) {
        for (Respuesta r : respuestas) {
            assertTrue(r.estado() < 500, "Error de servidor: " + r.estado() + " " + r.cuerpo());
        }
    }

    private void limpiarConsultasYEventos() {
        jdbc.update("DELETE FROM envio_notificacion");
        jdbc.update("DELETE FROM notificacion");
        jdbc.update("DELETE FROM consulta");
        jdbc.update("DELETE FROM turno_evento");
        jdbc.update("UPDATE turno SET estado = 'ACTIVO'");
    }

    private Respuesta reservar(String token, long numeroId) {
        return post("/api/consultas", token, "{\"numeroId\":%d}".formatted(numeroId));
    }

    private String filtro() {
        return "{\"medicoId\":%d,\"especialidadId\":%d,\"fechaDesde\":\"%s\",\"fechaHasta\":\"%s\"}"
                .formatted(idMedico, idEspecialidad, hoy(), hoy().plusDays(30));
    }

    private Respuesta suspender(String token, long turnoId, int confirmadas) {
        return post("/api/turnos/suspensiones", token,
                "{\"filtro\":%s,\"ids\":[%d],\"observacion\":\"Prueba\",\"cantidadConfirmada\":%d}"
                        .formatted(filtro(), turnoId, confirmadas));
    }

    private Respuesta rehabilitar(String token, long turnoId) {
        return post("/api/turnos/rehabilitaciones", token,
                "{\"filtro\":%s,\"ids\":[%d]}".formatted(filtro(), turnoId));
    }

    @Test
    void dosSociosReservanElMismoNumeroSoloUnoLoObtiene() throws Exception {
        long turno = sembrarTurno(hoy().plusDays(7), 1);
        long numero = numeroId(turno, 1);
        String a = tokenSocio(ciSocio1);
        String b = tokenSocio(ciSocio2);

        for (int ronda = 0; ronda < RONDAS; ronda++) {
            limpiarConsultasYEventos();
            List<Respuesta> r = enParalelo(List.of(() -> reservar(a, numero), () -> reservar(b, numero)));

            sinErroresDeServidor(r);
            assertEquals(1, contarEstado(r, 201), "Ronda " + ronda);
            assertEquals(1, contarEstado(r, 409), "Ronda " + ronda);
            assertEquals("NUMERO_NO_DISPONIBLE",
                    r.stream().filter(x -> x.estado() == 409).findFirst().orElseThrow().codigo());
            assertEquals(1, jdbc.queryForObject(
                    "SELECT count(*) FROM consulta WHERE id_numero = ? AND estado = 'AGENDADA'",
                    Integer.class, numero));
        }
    }

    @Test
    void reservaYSuspensionSimultaneasNuncaDejanUnaConsultaAgendadaEnUnTurnoSuspendido() throws Exception {
        String funcionario = tokenEmpleado(ciFuncionario);
        String socio = tokenSocio(ciSocio1);
        long turno = sembrarTurno(hoy().plusDays(8), 3);
        long numero = numeroId(turno, 1);

        for (int ronda = 0; ronda < RONDAS; ronda++) {
            limpiarConsultasYEventos();
            List<Respuesta> r = enParalelo(List.of(
                    () -> reservar(socio, numero),
                    () -> suspender(funcionario, turno, 0)));

            sinErroresDeServidor(r);
            String estado = jdbc.queryForObject("SELECT estado FROM turno WHERE id_turno = ?", String.class, turno);
            int agendadas = jdbc.queryForObject(
                    "SELECT count(*) FROM consulta WHERE estado = 'AGENDADA'", Integer.class);
            if (estado.equals("SUSPENDIDO")) {
                assertEquals(0, agendadas, "Ronda " + ronda + ": turno suspendido con consulta agendada");
            }
            assertTrue(contarEstado(r, 200) + contarEstado(r, 201) >= 1, "Ronda " + ronda + " " + r);
            int canceladasInstitucion = jdbc.queryForObject(
                    "SELECT count(*) FROM consulta WHERE estado = 'CANCELADA_INSTITUCION'", Integer.class);
            assertEquals(canceladasInstitucion, jdbc.queryForObject(
                    "SELECT count(*) FROM notificacion WHERE tipo = 'SUSPENSION'", Integer.class));
        }
    }

    @Test
    void suspensionYRehabilitacionSimultaneasDejanEventosCoherentesConElEstado() throws Exception {
        String f1 = tokenEmpleado(ciFuncionario);
        String f2 = tokenEmpleado(ciFuncionario2);
        long turno = sembrarTurno(hoy().plusDays(9), 2);

        for (int ronda = 0; ronda < RONDAS; ronda++) {
            limpiarConsultasYEventos();
            List<Respuesta> r = enParalelo(List.of(
                    () -> suspender(f1, turno, 0),
                    () -> rehabilitar(f2, turno)));

            sinErroresDeServidor(r);
            int suspensiones = jdbc.queryForObject(
                    "SELECT count(*) FROM turno_evento WHERE tipo = 'SUSPENSION'", Integer.class);
            int rehabilitaciones = jdbc.queryForObject(
                    "SELECT count(*) FROM turno_evento WHERE tipo = 'REHABILITACION'", Integer.class);
            String estado = jdbc.queryForObject("SELECT estado FROM turno WHERE id_turno = ?", String.class, turno);
            assertEquals(estado.equals("SUSPENDIDO") ? 1 : 0, suspensiones - rehabilitaciones,
                    "Ronda " + ronda + " estado=" + estado + " " + r);
            assertTrue(suspensiones >= 1, "La suspension debe haberse aplicado en la ronda " + ronda);
        }
    }

    @Test
    void rehabilitacionesConHorariosSuperpuestosDelMismoMedicoActivanComoMaximoUno() throws Exception {
        String f1 = tokenEmpleado(ciFuncionario);
        String f2 = tokenEmpleado(ciFuncionario2);
        java.time.LocalDate fecha = hoy().plusDays(10);
        long turnoA = sembrarTurno(fecha, 2);
        long turnoB = sembrarTurno(fecha, 2);

        for (int ronda = 0; ronda < RONDAS; ronda++) {
            jdbc.update("UPDATE turno SET estado = 'SUSPENDIDO'");
            List<Respuesta> r = enParalelo(List.of(() -> rehabilitar(f1, turnoA), () -> rehabilitar(f2, turnoB)));

            sinErroresDeServidor(r);
            int activos = jdbc.queryForObject(
                    "SELECT count(*) FROM turno WHERE estado = 'ACTIVO' AND fecha = ?", Integer.class, fecha);
            assertEquals(1, activos, "Ronda " + ronda + ": " + r);
            assertEquals(1, contarEstado(r, 409), "Ronda " + ronda + ": " + r);
            assertEquals("SOLAPAMIENTO_TURNO",
                    r.stream().filter(x -> x.estado() == 409).findFirst().orElseThrow().codigo());
        }
    }

    @Test
    void dosResultadosIncompatiblesSobreLaMismaConsultaSoloAplicaUno() throws Exception {
        long turno = sembrarTurno(hoy(), 1);
        long consulta = sembrarConsulta(idSocio1, numeroId(turno, 1));
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)",
                idSocio1, idFuncionario, hoy());
        String medico = tokenEmpleado(ciMedico);

        for (int ronda = 0; ronda < RONDAS; ronda++) {
            jdbc.update("DELETE FROM pase");
            jdbc.update("DELETE FROM atencion");
            jdbc.update("UPDATE consulta SET estado = 'AGENDADA', resultado_registrado_por = NULL,"
                    + " fecha_resultado = NULL WHERE id_consulta = ?", consulta);
            List<Respuesta> r = enParalelo(List.of(
                    () -> post("/api/medico/consultas/" + consulta + "/resultado", medico,
                            "{\"resultado\":\"ATENDIDA\",\"afeccion\":\"Gripe\"}"),
                    () -> post("/api/medico/consultas/" + consulta + "/resultado", medico,
                            "{\"resultado\":\"NO_SE_PRESENTO\"}")));

            sinErroresDeServidor(r);
            assertEquals(1, r.stream().filter(x -> x.estado() == 200).count(), "Ronda " + ronda + ": " + r);
            String estado = estadoConsulta(consulta);
            int atenciones = contar("atencion");
            assertFalse(estado.equals("AGENDADA"));
            assertEquals(estado.equals("ATENDIDA") ? 1 : 0, atenciones,
                    "Ronda " + ronda + ": estado " + estado + " con " + atenciones + " atenciones");
        }
    }
}
