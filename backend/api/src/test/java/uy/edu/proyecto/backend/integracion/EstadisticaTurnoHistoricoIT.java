package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/**
 * RF-40 con interpretacion historica: una fecha cuenta como ofrecida si estaba activa al terminar su dia
 * (America/Montevideo), reconstruido desde turno_evento. Cada caso usa un patron con una sola fecha.
 */
class EstadisticaTurnoHistoricoIT extends BaseIntegracionIT {

    private static final String RUTA = "/api/estadisticas/turnos";
    private static final String MARZO = "?desde=2026-03-01&hasta=2026-03-31";
    private static final String FECHA = "2026-03-09";

    private record Fecha(long patron, long turno, List<Long> numeros) {
    }

    private Fecha fecha(String fecha, String estadoActual, int cantidad) {
        long patron = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, 1, DATE '2026-01-01', DATE '2036-12-31')"
                        + " RETURNING id_turno_semanal",
                Long.class, idMedico, idEspecialidad, idConsultorio, idFuncionario);
        List<Long> semanales = new ArrayList<>();
        for (int i = 1; i <= cantidad; i++) {
            semanales.add(jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, patron, i, hora(540 + (i - 1) * 20), hora(560 + (i - 1) * 20)));
        }
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha, estado)"
                        + " VALUES (?, ?, ?::date, ?) RETURNING id_turno",
                Long.class, patron, idConsultorio, fecha, estadoActual);
        List<Long> numeros = new ArrayList<>();
        for (int i = 1; i <= cantidad; i++) {
            numeros.add(jdbc.queryForObject(
                    "INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?, ?::time, ?::time) RETURNING id_numero",
                    Long.class, turno, semanales.get(i - 1), i,
                    hora(540 + (i - 1) * 20), hora(560 + (i - 1) * 20)));
        }
        return new Fecha(patron, turno, numeros);
    }

    private void evento(Fecha f, String tipo, String instante) {
        jdbc.update("INSERT INTO turno_evento (id_turno, id_responsable, tipo, realizado_en)"
                + " VALUES (?, ?, ?, ?::timestamptz)", f.turno(), idFuncionario, tipo, instante);
    }

    private void reservar(long numero, long socio, boolean cancelada) {
        if (cancelada) {
            jdbc.update("INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por,"
                    + " cancelada_en) VALUES (?, ?, 'CANCELADA_SOCIO', '2026-02-20 10:00:00-03', ?,"
                    + " '2026-02-21 10:00:00-03')", socio, numero, socio);
        } else {
            jdbc.update("INSERT INTO consulta (id_socio, id_numero, estado, agendada_en)"
                    + " VALUES (?, ?, 'AGENDADA', '2026-02-20 10:00:00-03')", socio, numero);
        }
    }

    private JsonNode item(String consulta, long patron) {
        Respuesta r = get(RUTA + consulta, tokenEmpleado(ciAdmin));
        assertEquals(200, r.estado(), r.cuerpo());
        for (JsonNode item : r.json().path("items")) {
            if (item.path("turnoSemanalId").asLong() == patron) {
                return item;
            }
        }
        throw new AssertionError("Falta el patron " + patron);
    }

    private void ofrecidos(Fecha f, long esperados) {
        assertEquals(esperados, item(MARZO, f.patron()).path("numerosOfrecidos").asLong());
    }

    @Test
    void sinEventosUsaElEstadoActual() {
        ofrecidos(fecha(FECHA, "ACTIVO", 2), 2);
        ofrecidos(fecha(FECHA, "SUSPENDIDO", 2), 0);
    }

    @Test
    void suspensionAnteriorALaFechaLaExcluyeYRehabilitacionAnteriorLaIncluye() {
        Fecha suspendida = fecha(FECHA, "SUSPENDIDO", 2);
        evento(suspendida, "SUSPENSION", "2026-03-02 10:00:00-03");
        ofrecidos(suspendida, 0);

        Fecha rehabilitada = fecha(FECHA, "ACTIVO", 2);
        evento(rehabilitada, "SUSPENSION", "2026-03-02 10:00:00-03");
        evento(rehabilitada, "REHABILITACION", "2026-03-05 10:00:00-03");
        ofrecidos(rehabilitada, 2);
    }

    @Test
    void rehabilitacionPosteriorALaFechaNoLaHaceOfrecida() {
        Fecha f = fecha(FECHA, "ACTIVO", 3);
        evento(f, "SUSPENSION", "2026-03-02 10:00:00-03");
        evento(f, "REHABILITACION", "2026-03-20 10:00:00-03");
        ofrecidos(f, 0);
    }

    @Test
    void suspensionPosteriorALaFechaNoLaHaceDesaparecer() {
        Fecha f = fecha(FECHA, "SUSPENDIDO", 3);
        evento(f, "SUSPENSION", "2026-03-20 10:00:00-03");
        JsonNode item = item(MARZO, f.patron());
        assertEquals(3, item.path("numerosOfrecidos").asLong());
        assertEquals(1, item.path("fechasActivas").asLong());
    }

    @Test
    void variosEventosCronologicosDefinenElEstadoAlCorte() {
        Fecha activa = fecha(FECHA, "SUSPENDIDO", 2);
        evento(activa, "SUSPENSION", "2026-03-02 10:00:00-03");
        evento(activa, "REHABILITACION", "2026-03-03 10:00:00-03");
        evento(activa, "SUSPENSION", "2026-03-05 10:00:00-03");
        evento(activa, "REHABILITACION", "2026-03-06 10:00:00-03");
        evento(activa, "SUSPENSION", "2026-03-15 10:00:00-03");
        ofrecidos(activa, 2);

        Fecha inactiva = fecha(FECHA, "ACTIVO", 2);
        evento(inactiva, "SUSPENSION", "2026-03-02 10:00:00-03");
        evento(inactiva, "REHABILITACION", "2026-03-03 10:00:00-03");
        evento(inactiva, "SUSPENSION", "2026-03-05 10:00:00-03");
        evento(inactiva, "REHABILITACION", "2026-03-15 10:00:00-03");
        ofrecidos(inactiva, 0);
    }

    @Test
    void conEventosConLaMismaMarcaDecideElDeMayorIdentificador() {
        Fecha rehabilitaUltimo = fecha(FECHA, "ACTIVO", 2);
        evento(rehabilitaUltimo, "SUSPENSION", "2026-03-05 10:00:00-03");
        evento(rehabilitaUltimo, "REHABILITACION", "2026-03-05 10:00:00-03");
        ofrecidos(rehabilitaUltimo, 2);

        Fecha suspendeUltimo = fecha(FECHA, "SUSPENDIDO", 2);
        evento(suspendeUltimo, "REHABILITACION", "2026-03-05 10:00:00-03");
        evento(suspendeUltimo, "SUSPENSION", "2026-03-05 10:00:00-03");
        ofrecidos(suspendeUltimo, 0);
    }

    @Test
    void elCorteDelDiaSeEvaluaEnMontevideoYNoEnUtc() {
        // 23:30 en Montevideo del dia de la fecha ya es el dia siguiente en UTC: igual cuenta como dentro del dia.
        Fecha suspendidaAlFinal = fecha(FECHA, "SUSPENDIDO", 2);
        evento(suspendidaAlFinal, "SUSPENSION", "2026-03-09 23:30:00-03");
        ofrecidos(suspendidaAlFinal, 0);

        // 00:30 del dia siguiente en Montevideo: ya no afecta a la fecha, aunque sea el mismo dia UTC que 23:30-03.
        Fecha suspendidaDespues = fecha(FECHA, "SUSPENDIDO", 2);
        evento(suspendidaDespues, "SUSPENSION", "2026-03-10 00:30:00-03");
        ofrecidos(suspendidaDespues, 2);
    }

    @Test
    void primerEventoDeRehabilitacionImplicaEstadoInicialSuspendido() {
        Fecha antes = fecha(FECHA, "ACTIVO", 2);
        evento(antes, "REHABILITACION", "2026-03-05 10:00:00-03");
        ofrecidos(antes, 2);

        Fecha despues = fecha(FECHA, "ACTIVO", 2);
        evento(despues, "REHABILITACION", "2026-03-20 10:00:00-03");
        ofrecidos(despues, 0);
    }

    @Test
    void lasFechasDeHoyYFuturasUsanElEstadoVigenteAhora() {
        String hoy = hoy().toString();
        String futuro = hoy().plusDays(5).toString();

        Fecha hoySuspendida = fecha(hoy, "SUSPENDIDO", 2);
        jdbc.update("INSERT INTO turno_evento (id_turno, id_responsable, tipo, realizado_en)"
                + " VALUES (?, ?, 'SUSPENSION', now() - INTERVAL '1 minute')", hoySuspendida.turno(), idFuncionario);
        Fecha futuraSuspendida = fecha(futuro, "SUSPENDIDO", 2);
        jdbc.update("INSERT INTO turno_evento (id_turno, id_responsable, tipo, realizado_en)"
                + " VALUES (?, ?, 'SUSPENSION', now() - INTERVAL '1 minute')", futuraSuspendida.turno(), idFuncionario);
        Fecha futuraActiva = fecha(futuro, "ACTIVO", 2);

        String periodo = "?desde=" + hoy + "&hasta=" + futuro;
        assertEquals(0, item(periodo, hoySuspendida.patron()).path("numerosOfrecidos").asLong());
        assertEquals(0, item(periodo, futuraSuspendida.patron()).path("numerosOfrecidos").asLong());
        assertEquals(2, item(periodo, futuraActiva.patron()).path("numerosOfrecidos").asLong());
    }

    @Test
    void losEventosNoMultiplicanNumerosNiConsultas() {
        Fecha f = fecha(FECHA, "ACTIVO", 3);
        for (int i = 1; i <= 4; i++) {
            evento(f, "SUSPENSION", "2026-03-0" + i + " 08:00:00-03");
            evento(f, "REHABILITACION", "2026-03-0" + i + " 09:00:00-03");
        }
        reservar(f.numeros().get(0), idSocio1, true);
        reservar(f.numeros().get(0), idSocio2, false);
        reservar(f.numeros().get(1), idSocio3, true);

        JsonNode item = item(MARZO, f.patron());
        assertEquals(3, item.path("numerosOfrecidos").asLong());
        assertEquals(1, item.path("numerosOcupados").asLong());
        assertEquals("33.33 %", item.path("utilizacion").asString());
    }

    @Test
    void elHistoricoDistingueLaInterpretacionDelEstadoActual() {
        // A: sin eventos, activa (4 numeros, 2 ocupados).
        Fecha a = fecha(FECHA, "ACTIVO", 4);
        reservar(a.numeros().get(0), idSocio1, false);
        reservar(a.numeros().get(1), idSocio2, false);
        // B: hoy figura suspendida, pero lo estaba activa en su dia (4 numeros, 1 ocupado).
        Fecha b = fecha("2026-03-16", "SUSPENDIDO", 4);
        evento(b, "SUSPENSION", "2026-03-30 10:00:00-03");
        reservar(b.numeros().get(0), idSocio3, false);
        // C: hoy figura activa, pero estaba suspendida en su dia: no se ofrecio.
        Fecha c = fecha("2026-03-23", "ACTIVO", 4);
        evento(c, "SUSPENSION", "2026-03-10 10:00:00-03");
        evento(c, "REHABILITACION", "2026-03-30 10:00:00-03");

        // Los tres patrones son distintos: se consulta cada uno y se acumulan sus totales.
        long ofrecidos = 0;
        long ocupados = 0;
        for (Fecha f : List.of(a, b, c)) {
            JsonNode item = item(MARZO, f.patron());
            ofrecidos += item.path("numerosOfrecidos").asLong();
            ocupados += item.path("numerosOcupados").asLong();
        }
        assertEquals(8, ofrecidos);
        assertEquals(3, ocupados);
    }

    @Test
    void numeradorCeroDenominadorCeroYFiltroDeFechas() {
        Fecha libre = fecha(FECHA, "ACTIVO", 2);
        JsonNode cero = item(MARZO, libre.patron());
        assertEquals("0 %", cero.path("utilizacion").asString());

        Fecha sinDatos = fecha(FECHA, "SUSPENDIDO", 2);
        evento(sinDatos, "SUSPENSION", "2026-03-02 10:00:00-03");
        JsonNode vacio = item(MARZO, sinDatos.patron());
        assertEquals("Sin datos", vacio.path("utilizacion").asString());
        assertTrue(vacio.path("porcentajeUtilizacion").isNull());

        JsonNode otroPeriodo = item("?desde=2026-04-01&hasta=2026-04-30", libre.patron());
        assertEquals(0, otroPeriodo.path("numerosOfrecidos").asLong());
    }
}
