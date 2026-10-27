package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-40 contra PostgreSQL real: ocupados / ofrecidos en las fechas activas del periodo. */
class EstadisticaTurnoIT extends BaseIntegracionIT {

    private static final String RUTA = "/api/estadisticas/turnos";
    private static final String MARZO = "?desde=2026-03-01&hasta=2026-03-31";

    private record Patron(long id, List<Long> semanales) {
    }

    private Patron patron(long especialidadId, String inicio, String fin, int cantidad) {
        long id = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, 1, ?::date, ?::date) RETURNING id_turno_semanal",
                Long.class, idMedico, especialidadId, idConsultorio, idFuncionario, inicio, fin);
        List<Long> semanales = new ArrayList<>();
        for (int i = 1; i <= cantidad; i++) {
            int minutos = 9 * 60 + (i - 1) * 20;
            semanales.add(jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, id, i, hora(minutos), hora(minutos + 20)));
        }
        return new Patron(id, semanales);
    }

    private long turno(Patron patron, String fecha, String estado) {
        return jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha, estado)"
                        + " VALUES (?, ?, ?::date, ?) RETURNING id_turno",
                Long.class, patron.id(), idConsultorio, fecha, estado);
    }

    private List<Long> numeros(Patron patron, long turno, int cantidad) {
        List<Long> ids = new ArrayList<>();
        for (int i = 1; i <= cantidad; i++) {
            int minutos = 9 * 60 + (i - 1) * 20;
            ids.add(jdbc.queryForObject(
                    "INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?, ?::time, ?::time) RETURNING id_numero",
                    Long.class, turno, patron.semanales().get(i - 1), i,
                    hora(minutos), hora(minutos + 20)));
        }
        return ids;
    }

    private List<Long> fecha(Patron patron, String fecha, String estado, int cantidad) {
        return numeros(patron, turno(patron, fecha, estado), cantidad);
    }

    private void reserva(long numero, long socio, String estado) {
        switch (estado) {
            case "AGENDADA" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en)"
                            + " VALUES (?, ?, 'AGENDADA', '2026-02-20 10:00:00-03')", socio, numero);
            case "ATENDIDA", "NO_SE_PRESENTO" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en,"
                            + " resultado_registrado_por, fecha_resultado)"
                            + " VALUES (?, ?, ?, '2026-02-20 10:00:00-03', ?, '2026-03-02 12:00:00-03')",
                    socio, numero, estado, idMedico);
            case "CANCELADA_SOCIO" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por,"
                            + " cancelada_en) VALUES (?, ?, 'CANCELADA_SOCIO',"
                            + " '2026-02-20 10:00:00-03', ?, '2026-02-21 10:00:00-03')",
                    socio, numero, socio);
            case "CANCELADA_INSTITUCION" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por,"
                            + " cancelada_en, motivo_cancelacion) VALUES (?, ?, 'CANCELADA_INSTITUCION',"
                            + " '2026-02-20 10:00:00-03', ?, '2026-02-21 10:00:00-03', 'Medico ausente')",
                    socio, numero, idFuncionario);
            default -> throw new IllegalArgumentException(estado);
        }
    }

    private long patronGeneral;
    private long patronSinActivas;
    private long patronSinOcupacion;

    /** Marzo 2026: un patron con ocupacion mixta, otro sin fechas activas y otro sin reservas. */
    private void sembrarMarzo() {
        Patron general = patron(idEspecialidad, "2026-01-01", "2026-12-31", 5);
        patronGeneral = general.id();

        // A: cuatro estados ocupados (dos derivados) y un numero libre.
        List<Long> a = fecha(general, "2026-03-02", "ACTIVO", 5);
        reserva(a.get(0), idSocio1, "AGENDADA");   // fecha pasada con aviso de llegada: NO_ATENDIDA
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, DATE '2026-03-02')",
                idSocio1, idFuncionario);
        reserva(a.get(1), idSocio2, "AGENDADA");   // fecha pasada sin aviso: NO_ASISTIO
        reserva(a.get(2), idSocio3, "ATENDIDA");
        reserva(a.get(3), idSocio4, "NO_SE_PRESENTO");

        // B: reserva cancelada y luego reservada otra vez (un solo ocupado), todo cancelado, y una vigente.
        List<Long> b = fecha(general, "2026-03-09", "ACTIVO", 4);
        reserva(b.get(0), idSocio1, "CANCELADA_SOCIO");
        reserva(b.get(0), idSocio2, "AGENDADA");
        reserva(b.get(1), idSocio3, "CANCELADA_INSTITUCION");
        reserva(b.get(2), idSocio4, "CANCELADA_SOCIO");
        reserva(b.get(2), idSocio1, "CANCELADA_SOCIO");
        reserva(b.get(3), idSocio3, "AGENDADA");

        // C: fecha suspendida: sus numeros no se ofrecen y no cuentan.
        List<Long> c = fecha(general, "2026-03-16", "SUSPENDIDO", 4);
        for (int i = 0; i < c.size(); i++) {
            reserva(c.get(i), idSocio1, "CANCELADA_INSTITUCION");
        }

        // D: suspendida y rehabilitada: vuelve a ser activa; lo cancelado por la suspension queda libre.
        long turnoD = turno(general, "2026-03-23", "ACTIVO");
        List<Long> d = numeros(general, turnoD, 4);
        long evento = jdbc.queryForObject(
                "INSERT INTO turno_evento (id_turno, id_responsable, tipo) VALUES (?, ?, 'SUSPENSION')"
                        + " RETURNING id_evento", Long.class, turnoD, idFuncionario);
        jdbc.update("INSERT INTO turno_evento (id_turno, id_responsable, tipo) VALUES (?, ?, 'REHABILITACION')",
                turnoD, idFuncionario);
        jdbc.update(
                "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por, cancelada_en,"
                        + " id_evento_suspension) VALUES (?, ?, 'CANCELADA_INSTITUCION',"
                        + " '2026-02-20 10:00:00-03', ?, '2026-03-10 10:00:00-03', ?)",
                idSocio1, d.get(0), idFuncionario, evento);
        reserva(d.get(1), idSocio2, "AGENDADA");   // reservado despues de la rehabilitacion

        // Limites inclusivos del periodo: 01/03 libre y 31/03 totalmente reservada.
        fecha(general, "2026-03-01", "ACTIVO", 2);
        List<Long> g = fecha(general, "2026-03-31", "ACTIVO", 2);
        reserva(g.get(0), idSocio1, "AGENDADA");
        reserva(g.get(1), idSocio2, "AGENDADA");

        // Fuera del periodo: no participa en el porcentaje de marzo.
        List<Long> fuera = fecha(general, "2026-04-01", "ACTIVO", 3);
        reserva(fuera.get(0), idSocio3, "AGENDADA");
        fecha(general, "2026-02-28", "ACTIVO", 3);

        // Patron cuya unica fecha de marzo esta suspendida: denominador cero.
        Patron sinActivas = patron(idEspecialidadConPase, "2026-03-01", "2026-03-31", 2);
        patronSinActivas = sinActivas.id();
        fecha(sinActivas, "2026-03-10", "SUSPENDIDO", 2);

        // Patron activo sin ninguna reserva: ocupacion cero con denominador positivo.
        Patron sinOcupacion = patron(idEspecialidadConPase, "2026-03-01", "2026-03-31", 3);
        patronSinOcupacion = sinOcupacion.id();
        fecha(sinOcupacion, "2026-03-12", "ACTIVO", 3);

        // Patron vigente solo en abril: no aparece en marzo.
        Patron abril = patron(idEspecialidadConPase, "2026-04-01", "2026-04-30", 1);
        fecha(abril, "2026-04-06", "ACTIVO", 1);
    }

    private JsonNode consultar(String token, String consulta) {
        Respuesta r = get(RUTA + consulta, token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    private static JsonNode item(JsonNode items, long patronId) {
        for (JsonNode item : items) {
            if (item.path("turnoSemanalId").asLong() == patronId) {
                return item;
            }
        }
        throw new AssertionError("Falta el turno " + patronId);
    }

    @Test
    void calculaOcupacionPorTurnoSinDuplicarNumerosNiContarFechasSuspendidas() {
        sembrarMarzo();

        JsonNode json = consultar(tokenEmpleado(ciAdmin), MARZO);

        assertEquals("2026-03-01", json.path("desde").asString());
        assertEquals("2026-03-31", json.path("hasta").asString());
        JsonNode items = json.path("items");
        assertEquals(3, items.size());

        // Activas: A, B, D, 01/03 y 31/03. Ofrecidos 5+4+4+2+2; ocupados 4+2+1+0+2.
        JsonNode general = item(items, patronGeneral);
        assertEquals(5, general.path("fechasActivas").asLong());
        assertEquals(17, general.path("numerosOfrecidos").asLong());
        assertEquals(9, general.path("numerosOcupados").asLong());
        assertEquals(52.94, general.path("porcentajeUtilizacion").asDouble(), 0.0001);
        assertEquals("52.94 %", general.path("utilizacion").asString());
        assertEquals("Medicina General", general.path("especialidad").path("nombre").asString());
        assertEquals("Mario", general.path("medico").path("nombre").asString());

        JsonNode sinActivas = item(items, patronSinActivas);
        assertEquals(0, sinActivas.path("fechasActivas").asLong());
        assertEquals(0, sinActivas.path("numerosOfrecidos").asLong());
        assertEquals("Sin datos", sinActivas.path("utilizacion").asString());
        assertTrue(sinActivas.path("porcentajeUtilizacion").isNull());

        JsonNode sinOcupacion = item(items, patronSinOcupacion);
        assertEquals(3, sinOcupacion.path("numerosOfrecidos").asLong());
        assertEquals(0, sinOcupacion.path("numerosOcupados").asLong());
        assertEquals("0 %", sinOcupacion.path("utilizacion").asString());
    }

    @Test
    void elTotalCoincideConUnaConsultaIndependienteSobreNumerosDistintos() {
        sembrarMarzo();

        JsonNode general = item(consultar(tokenEmpleado(ciAdmin), MARZO).path("items"), patronGeneral);

        Long ocupadosEnBase = jdbc.queryForObject(
                "SELECT count(DISTINCT c.id_numero) FROM consulta c"
                        + " JOIN numero n ON n.id_numero = c.id_numero"
                        + " JOIN turno t ON t.id_turno = n.id_turno"
                        + " WHERE t.id_turno_semanal = ? AND t.estado = 'ACTIVO'"
                        + " AND t.fecha BETWEEN '2026-03-01' AND '2026-03-31'"
                        + " AND c.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')",
                Long.class, patronGeneral);
        Long reservasHistoricasEnBase = jdbc.queryForObject(
                "SELECT count(*) FROM consulta c JOIN numero n ON n.id_numero = c.id_numero"
                        + " JOIN turno t ON t.id_turno = n.id_turno WHERE t.id_turno_semanal = ?"
                        + " AND t.fecha BETWEEN '2026-03-01' AND '2026-03-31'",
                Long.class, patronGeneral);
        assertEquals(ocupadosEnBase, general.path("numerosOcupados").asLong());
        assertTrue(reservasHistoricasEnBase > ocupadosEnBase,
                "El escenario debe tener reservas historicas que no se cuentan dos veces");
    }

    @Test
    void losLimitesDelPeriodoSonInclusivosYSeleccionanSoloEsasFechas() {
        sembrarMarzo();
        String admin = tokenEmpleado(ciAdmin);

        JsonNode primerDia = item(
                consultar(admin, "?desde=2026-03-01&hasta=2026-03-01").path("items"), patronGeneral);
        assertEquals(1, primerDia.path("fechasActivas").asLong());
        assertEquals(2, primerDia.path("numerosOfrecidos").asLong());
        assertEquals("0 %", primerDia.path("utilizacion").asString());

        JsonNode ultimoDia = item(
                consultar(admin, "?desde=2026-03-31&hasta=2026-03-31").path("items"), patronGeneral);
        assertEquals("100 %", ultimoDia.path("utilizacion").asString());

        JsonNode abril = item(
                consultar(admin, "?desde=2026-04-01&hasta=2026-04-01").path("items"), patronGeneral);
        assertEquals(3, abril.path("numerosOfrecidos").asLong());
        assertEquals(1, abril.path("numerosOcupados").asLong());
        assertEquals("33.33 %", abril.path("utilizacion").asString());
    }

    @Test
    void periodoSinTurnosVigentesDevuelveListaVacia() {
        sembrarMarzo();

        JsonNode items = consultar(tokenEmpleado(ciAdmin), "?desde=2020-01-01&hasta=2020-01-31").path("items");

        assertEquals(0, items.size());
    }

    @Test
    void sinParametrosUsaElMesEnCursoEnMontevideo() {
        LocalDate hoy = hoy();
        Patron patron = patron(idEspecialidad, hoy.withDayOfMonth(1).toString(),
                hoy.withDayOfMonth(hoy.lengthOfMonth()).toString(), 2);
        List<Long> numeros = fecha(patron, hoy.toString(), "ACTIVO", 2);
        reserva(numeros.get(0), idSocio1, "AGENDADA");

        JsonNode json = consultar(tokenEmpleado(ciAdmin), "");

        assertEquals(hoy.withDayOfMonth(1).toString(), json.path("desde").asString());
        assertEquals(hoy.withDayOfMonth(hoy.lengthOfMonth()).toString(), json.path("hasta").asString());
        JsonNode item = item(json.path("items"), patron.id());
        assertEquals(2, item.path("numerosOfrecidos").asLong());
        assertEquals("50 %", item.path("utilizacion").asString());
    }

    @Test
    void soloElAdministradorAccede() {
        sembrarMarzo();

        assertEquals(401, get(RUTA, null).estado());
        assertEquals(403, get(RUTA, tokenSocio(ciSocio1)).estado());
        assertEquals(403, get(RUTA, tokenEmpleado(ciFuncionario)).estado());
        assertEquals(403, get(RUTA, tokenEmpleado(ciMedico)).estado());
        assertEquals(200, get(RUTA, tokenEmpleado(ciAdmin)).estado());
    }

    @Test
    void rangosInvalidosYTextoMaliciosoDevuelven400SinAlterarLaBase() {
        sembrarMarzo();
        String admin = tokenEmpleado(ciAdmin);
        int[] antes = {contar("consulta"), contar("numero"), contar("turno")};

        for (String consulta : List.of(
                "?desde=2026-03-31&hasta=2026-03-01",
                "?desde=31/03/2026",
                "?hasta=2026-02-30",
                "?desde=2026-03-01'%20OR%20'1'='1",
                "?desde=2026-03-01;%20DROP%20TABLE%20consulta;--")) {
            Respuesta r = get(RUTA + consulta, admin);
            assertEquals(400, r.estado(), consulta + " -> " + r.cuerpo());
            assertEquals("VALIDACION", r.codigo());
        }

        assertArrayEquals(antes, new int[] {contar("consulta"), contar("numero"), contar("turno")});
    }

    @Test
    void laRespuestaNoExponeDatosDePacientes() {
        sembrarMarzo();

        String cuerpo = get(RUTA + MARZO, tokenEmpleado(ciAdmin)).cuerpo();

        for (String sensible : List.of(ciSocio1, ciSocio2, "Sofia", "Soca", "@ejemplo.invalid", "idSocio")) {
            assertFalse(cuerpo.contains(sensible), "No debe exponer " + sensible);
        }
    }

    @Test
    void consultasConcurrentesDevuelvenElMismoResultadoMientrasSeReservaOtroTurno() throws Exception {
        sembrarMarzo();
        String admin = tokenEmpleado(ciAdmin);
        String esperado = item(consultar(admin, MARZO).path("items"), patronGeneral).toString();

        ExecutorService pool = Executors.newFixedThreadPool(6);
        try {
            List<Future<String>> tareas = new ArrayList<>();
            for (int i = 0; i < 6; i++) {
                Callable<String> tarea = () -> item(
                        consultar(admin, MARZO).path("items"), patronGeneral).toString();
                tareas.add(pool.submit(tarea));
            }
            for (Future<String> tarea : tareas) {
                assertEquals(esperado, tarea.get());
            }
        } finally {
            pool.shutdownNow();
        }
    }
}
