package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
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
 * Nuevas reservas tras una inasistencia: una consulta AGENDADA cuyo dia ya termino sin resultado es el
 * estado derivado NO_ASISTIO / NO_ATENDIDA y no cuenta para el limite de tres ni el de una por especialidad.
 */
class ReservasTrasInasistenciaIT extends BaseIntegracionIT {

    private long especialidadExtra(String nombre) {
        long id = jdbc.queryForObject(
                "INSERT INTO especialidad (nombre, requiere_pase) VALUES (?, false) RETURNING id_especialidad",
                Long.class, nombre);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", idMedico, id);
        return id;
    }

    /** Turno de una fecha en la especialidad indicada, con un numero. */
    private long numeroEn(long especialidad, LocalDate fecha) {
        long turno = sembrarTurno(fecha, 1);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ? WHERE id_turno_semanal"
                + " = (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)", especialidad, turno);
        return numeroId(turno, 1);
    }

    /** Consulta AGENDADA persistida del socio (como las deja el sistema: nunca se reescribe sola). */
    private long agendada(long socio, long especialidad, LocalDate fecha) {
        return sembrarConsulta(socio, numeroEn(especialidad, fecha));
    }

    private Respuesta reservar(String token, long numeroId) {
        return post("/api/consultas", token, "{\"numeroId\":%d}".formatted(numeroId));
    }

    private void avisoLlegada(long socio, LocalDate fecha) {
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)",
                socio, idFuncionario, fecha);
    }

    private String estadoEnHistorial(String token, long consulta) {
        return get("/api/consultas/" + consulta, token).json().path("estado").asString();
    }

    @Test
    void consultaFuturaBloqueaLaMismaEspecialidad() {
        agendada(idSocio1, idEspecialidad, hoy().plusDays(5));

        Respuesta r = reservar(tokenSocio(ciSocio1), numeroEn(idEspecialidad, hoy().plusDays(6)));

        assertEquals(409, r.estado());
        assertEquals("LIMITE_ESPECIALIDAD", r.codigo());
    }

    @Test
    void consultaDelDiaActualSigueBloqueando() {
        agendada(idSocio1, idEspecialidad, hoy());

        Respuesta r = reservar(tokenSocio(ciSocio1), numeroEn(idEspecialidad, hoy().plusDays(6)));

        assertEquals(409, r.estado());
        assertEquals("LIMITE_ESPECIALIDAD", r.codigo());
    }

    @Test
    void nuevaReservaTrasNoAsistioQuedaPermitidaYElHistoricoNoSeToca() {
        long pasada = agendada(idSocio1, idEspecialidad, hoy().minusDays(1));
        String token = tokenSocio(ciSocio1);
        assertEquals("NO_ASISTIO", estadoEnHistorial(token, pasada));

        Respuesta r = reservar(token, numeroEn(idEspecialidad, hoy().plusDays(6)));

        assertEquals(201, r.estado(), r.cuerpo());
        assertEquals("AGENDADA", estadoConsulta(pasada), "El estado historico no se reescribe");
        assertEquals("NO_ASISTIO", estadoEnHistorial(token, pasada));
        assertNull(jdbc.queryForObject("SELECT id_pase FROM consulta WHERE id_consulta = ?", Long.class, pasada));
        assertEquals(2, contar("consulta"));
    }

    @Test
    void nuevaReservaTrasNoAtendidaQuedaPermitida() {
        LocalDate ayer = hoy().minusDays(1);
        long pasada = agendada(idSocio1, idEspecialidad, ayer);
        avisoLlegada(idSocio1, ayer);
        String token = tokenSocio(ciSocio1);
        assertEquals("NO_ATENDIDA", estadoEnHistorial(token, pasada));

        Respuesta r = reservar(token, numeroEn(idEspecialidad, hoy().plusDays(6)));

        assertEquals(201, r.estado(), r.cuerpo());
        assertEquals("AGENDADA", estadoConsulta(pasada));
    }

    @Test
    void elCambioDeDiaSeMideEnMontevideo() {
        // Ayer (Montevideo) ya termino; hoy no. La base usa su propia fecha y debe coincidir con hoy().
        assertEquals(hoy(), jdbc.queryForObject(
                "SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'America/Montevideo')::date", LocalDate.class));
        agendada(idSocio1, idEspecialidad, hoy().minusDays(1));
        long hoyConsulta = agendada(idSocio1, especialidadExtra("Pediatria"), hoy());
        String token = tokenSocio(ciSocio1);

        assertEquals(409, reservar(token, numeroEn(jdbc.queryForObject(
                "SELECT id_especialidad FROM especialidad WHERE nombre = 'Pediatria'", Long.class),
                hoy().plusDays(4))).estado());
        assertEquals(201, reservar(token, numeroEn(idEspecialidad, hoy().plusDays(5))).estado());
        assertEquals("AGENDADA", estadoConsulta(hoyConsulta));
    }

    @Test
    void limiteDeTresConsultasConsideraSoloLasPendientes() {
        long e2 = especialidadExtra("Pediatria");
        long e3 = especialidadExtra("Dermatologia");
        long e4 = especialidadExtra("Oftalmologia");
        agendada(idSocio1, idEspecialidad, hoy().minusDays(2));
        agendada(idSocio1, e2, hoy().minusDays(1));
        agendada(idSocio1, e3, hoy().plusDays(3));
        String token = tokenSocio(ciSocio1);

        assertEquals(201, reservar(token, numeroEn(e4, hoy().plusDays(4))).estado());
        assertEquals(201, reservar(token, numeroEn(idEspecialidad, hoy().plusDays(5))).estado());

        Respuesta cuarta = reservar(token, numeroEn(e2, hoy().plusDays(6)));
        assertEquals(409, cuarta.estado());
        assertEquals("LIMITE_TOTAL", cuarta.codigo());
    }

    @Test
    void tresConsultasFuturasSiguenBloqueandoElLimiteTotal() {
        long e2 = especialidadExtra("Pediatria");
        long e3 = especialidadExtra("Dermatologia");
        long e4 = especialidadExtra("Oftalmologia");
        agendada(idSocio1, idEspecialidad, hoy().plusDays(2));
        agendada(idSocio1, e2, hoy().plusDays(3));
        agendada(idSocio1, e3, hoy().plusDays(4));

        Respuesta r = reservar(tokenSocio(ciSocio1), numeroEn(e4, hoy().plusDays(5)));

        assertEquals(409, r.estado());
        assertEquals("LIMITE_TOTAL", r.codigo());
    }

    @Test
    void laInasistenciaNoAfectaLosLimitesDeOtroSocioNiPermiteReservarSinSesionOConOtroRol() {
        agendada(idSocio1, idEspecialidad, hoy().minusDays(1));
        agendada(idSocio2, idEspecialidad, hoy().plusDays(3));
        long numero = numeroEn(idEspecialidad, hoy().plusDays(6));

        Respuesta socio2 = reservar(tokenSocio(ciSocio2), numero);
        assertEquals(409, socio2.estado());
        assertEquals("LIMITE_ESPECIALIDAD", socio2.codigo());
        assertEquals(401, reservar(null, numero).estado());
        assertEquals(403, reservar(tokenEmpleado(ciFuncionario), numero).estado());
        assertEquals(2, contar("consulta"));
    }

    @Test
    void dosReservasSimultaneasTrasInasistenciaRespetanElLimiteTotal() throws Exception {
        long e2 = especialidadExtra("Pediatria");
        long e3 = especialidadExtra("Dermatologia");
        long e4 = especialidadExtra("Oftalmologia");
        agendada(idSocio1, idEspecialidad, hoy().minusDays(3));
        agendada(idSocio1, e2, hoy().plusDays(2));
        agendada(idSocio1, e3, hoy().plusDays(3));
        String token = tokenSocio(ciSocio1);
        long a = numeroEn(e4, hoy().plusDays(5));
        long b = numeroEn(idEspecialidad, hoy().plusDays(6));

        CyclicBarrier barrera = new CyclicBarrier(2);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            List<Future<Respuesta>> futuros = new ArrayList<>();
            for (long numero : List.of(a, b)) {
                Callable<Respuesta> tarea = () -> {
                    barrera.await(20, TimeUnit.SECONDS);
                    return reservar(token, numero);
                };
                futuros.add(pool.submit(tarea));
            }
            long creadas = 0;
            long limites = 0;
            for (Future<Respuesta> futuro : futuros) {
                Respuesta r = futuro.get(60, TimeUnit.SECONDS);
                assertTrue(r.estado() < 500, r.cuerpo());
                creadas += r.estado() == 201 ? 1 : 0;
                limites += r.estado() == 409 && "LIMITE_TOTAL".equals(r.codigo()) ? 1 : 0;
            }
            assertEquals(1, creadas);
            assertEquals(1, limites);
        } finally {
            pool.shutdownNow();
        }
        assertEquals(3, jdbc.queryForObject(
                "SELECT count(*) FROM consulta c JOIN numero n USING (id_numero) JOIN turno t USING (id_turno)"
                        + " WHERE c.id_socio = ? AND c.estado = 'AGENDADA' AND t.fecha >= ?",
                Integer.class, idSocio1, hoy()));
    }
}
