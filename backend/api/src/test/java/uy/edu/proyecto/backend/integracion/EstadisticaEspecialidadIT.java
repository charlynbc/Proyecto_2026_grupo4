package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-39 contra PostgreSQL real: periodo por fecha de agendamiento, canceladas incluidas. */
class EstadisticaEspecialidadIT extends BaseIntegracionIT {

    private static final String RUTA = "/api/estadisticas/especialidades";

    private long idPediatria;

    private long especialidad(String nombre, boolean requierePase) {
        return jdbc.queryForObject(
                "INSERT INTO especialidad (nombre, requiere_pase) VALUES (?, ?) RETURNING id_especialidad",
                Long.class, nombre, requierePase);
    }

    /** Crea patron semanal, turno de una fecha y sus numeros; devuelve los id_numero. */
    private List<Long> numeros(long especialidadId, LocalDate fecha, int cantidad) {
        long patron = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, idMedico, especialidadId, idConsultorio, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha)"
                        + " VALUES (?, ?, ?) RETURNING id_turno",
                Long.class, patron, idConsultorio, fecha);
        List<Long> ids = new ArrayList<>();
        for (int i = 1; i <= cantidad; i++) {
            int inicio = 9 * 60 + (i - 1) * 20;
            long semanal = jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, patron, i, hora(inicio), hora(inicio + 20));
            ids.add(jdbc.queryForObject(
                    "INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?, ?::time, ?::time) RETURNING id_numero",
                    Long.class, turno, semanal, i, hora(inicio), hora(inicio + 20)));
        }
        return ids;
    }

    private void agendar(long numeroId, long socioId, String agendadaEn) {
        jdbc.update(
                "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en)"
                        + " VALUES (?, ?, 'AGENDADA', ?::timestamptz)",
                socioId, numeroId, agendadaEn);
    }

    private void agendarYCancelarPorSocio(long numeroId, long socioId, String agendadaEn) {
        jdbc.update(
                "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por,"
                        + " cancelada_en) VALUES (?, ?, 'CANCELADA_SOCIO', ?::timestamptz, ?,"
                        + " ?::timestamptz + interval '1 hour')",
                socioId, numeroId, agendadaEn, socioId, agendadaEn);
    }

    private void agendarYCancelarPorInstitucion(long numeroId, long socioId, String agendadaEn) {
        jdbc.update(
                "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por,"
                        + " cancelada_en, motivo_cancelacion) VALUES (?, ?, 'CANCELADA_INSTITUCION',"
                        + " ?::timestamptz, ?, ?::timestamptz + interval '1 hour', 'Medico ausente')",
                socioId, numeroId, agendadaEn, idFuncionario, agendadaEn);
    }

    private void sembrarMarzo() {
        long cardiologia = idEspecialidadConPase;
        idPediatria = especialidad("Pediatria", false);

        // Medicina General: turnos en abril, reservas en febrero, marzo y abril.
        List<Long> mg = numeros(idEspecialidad, LocalDate.parse("2026-04-20"), 7);
        agendar(mg.get(0), idSocio1, "2026-03-01 00:00:00-03");                // limite inferior: cuenta
        agendar(mg.get(1), idSocio2, "2026-03-15 10:00:00-03");                // cuenta
        agendarYCancelarPorSocio(mg.get(2), idSocio3, "2026-03-20 11:00:00-03"); // cancelada: cuenta
        agendar(mg.get(2), idSocio4, "2026-03-25 09:00:00-03");                // nueva reserva del mismo numero
        agendar(mg.get(3), idSocio1, "2026-02-28 23:30:00-03");                // antes: no cuenta
        agendar(mg.get(4), idSocio2, "2026-04-01 00:00:00-03");                // limite superior exclusivo: no
        agendar(mg.get(5), idSocio3, "2026-03-31 23:59:59-03");                // ultimo segundo: cuenta
        agendar(mg.get(6), idSocio4, "2026-04-01 02:30:00+00");                // 23:30 del 31/03 en Montevideo: cuenta

        // Cardiologia: la fecha medica cae en marzo pero una reserva se hizo en febrero.
        List<Long> cardio = numeros(cardiologia, LocalDate.parse("2026-03-10"), 3);
        agendar(cardio.get(0), idSocio1, "2026-03-05 08:00:00-03");            // cuenta
        agendarYCancelarPorInstitucion(cardio.get(1), idSocio2, "2026-03-06 08:00:00-03"); // cuenta
        agendar(cardio.get(2), idSocio3, "2026-02-20 08:00:00-03");            // fuera por fecha de reserva
    }

    private JsonNode consultar(String token, String consulta) {
        Respuesta r = get(RUTA + consulta, token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    private static long cantidad(JsonNode items, String nombre) {
        for (JsonNode item : items) {
            if (nombre.equals(item.path("especialidad").path("nombre").asString())) {
                return item.path("cantidadConsultas").asLong();
            }
        }
        throw new AssertionError("Falta la especialidad " + nombre);
    }

    @Test
    void cuentaPorFechaDeReservaIncluyendoCanceladasYSinDuplicados() {
        sembrarMarzo();

        JsonNode json = consultar(tokenEmpleado(ciAdmin), "?desde=2026-03-01&hasta=2026-03-31");

        assertEquals("2026-03-01", json.path("desde").asString());
        assertEquals("2026-03-31", json.path("hasta").asString());
        JsonNode items = json.path("items");
        assertEquals(3, items.size());
        assertEquals(6, cantidad(items, "Medicina General"));
        assertEquals(2, cantidad(items, "Cardiologia"));
        assertEquals(0, cantidad(items, "Pediatria"));
        assertEquals("Medicina General", items.get(0).path("especialidad").path("nombre").asString());
        assertEquals("Pediatria", items.get(2).path("especialidad").path("nombre").asString());

        long total = items.get(0).path("cantidadConsultas").asLong()
                + items.get(1).path("cantidadConsultas").asLong()
                + items.get(2).path("cantidadConsultas").asLong();
        Long esperadoEnBase = jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE agendada_en >= '2026-03-01 00:00:00-03'"
                        + " AND agendada_en < '2026-04-01 00:00:00-03'",
                Long.class);
        assertEquals(esperadoEnBase, total, "La suma por especialidad debe igualar las consultas del periodo");
    }

    @Test
    void laFechaDeLaAtencionMedicaNoDefineElPeriodo() {
        sembrarMarzo();

        // Todas las atenciones de Medicina General son en abril: el periodo de abril solo
        // recibe la reserva del 01/04 00:00 hora local (la de las 02:30Z ya se contó en marzo).
        JsonNode abril = consultar(tokenEmpleado(ciAdmin), "?desde=2026-04-01&hasta=2026-04-30").path("items");
        assertEquals(1, cantidad(abril, "Medicina General"));
        assertEquals(0, cantidad(abril, "Cardiologia"));

        // Cardiologia tiene fecha medica en marzo, pero solo cuenta lo reservado en el periodo.
        JsonNode febrero = consultar(tokenEmpleado(ciAdmin), "?desde=2026-02-01&hasta=2026-02-28").path("items");
        assertEquals(1, cantidad(febrero, "Cardiologia"));
        assertEquals(1, cantidad(febrero, "Medicina General"));
    }

    @Test
    void periodoSinDatosDevuelveTodasLasEspecialidadesEnCero() {
        sembrarMarzo();

        JsonNode items = consultar(tokenEmpleado(ciAdmin), "?desde=2020-01-01&hasta=2020-01-31").path("items");

        assertEquals(3, items.size());
        for (JsonNode item : items) {
            assertEquals(0, item.path("cantidadConsultas").asLong());
        }
    }

    @Test
    void sinParametrosUsaElMesEnCursoEnMontevideo() {
        LocalDate hoy = hoy();
        List<Long> numeros = numeros(idEspecialidad, hoy.plusDays(7), 2);
        agendar(numeros.get(0), idSocio1, hoy.atStartOfDay(ZONA).plusHours(1).toOffsetDateTime().toString());
        Timestamp antesDelMes = Timestamp.from(
                hoy.withDayOfMonth(1).atStartOfDay(ZONA).minusSeconds(1).toInstant());
        jdbc.update(
                "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en) VALUES (?, ?, 'AGENDADA', ?)",
                idSocio2, numeros.get(1), antesDelMes);

        JsonNode json = consultar(tokenEmpleado(ciAdmin), "");

        assertEquals(hoy.withDayOfMonth(1).toString(), json.path("desde").asString());
        assertEquals(hoy.withDayOfMonth(hoy.lengthOfMonth()).toString(), json.path("hasta").asString());
        assertEquals(1, cantidad(json.path("items"), "Medicina General"));
    }

    @Test
    void soloElAdministradorAccedeYLosDemasRolesRecibenElRechazoCorrespondiente() {
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
        int[] antes = {contar("consulta"), contar("especialidad"), contar("turno")};

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

        assertArrayEquals(antes, new int[] {contar("consulta"), contar("especialidad"), contar("turno")});
    }
}
