package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/**
 * RF-41 contra PostgreSQL real: consultas del periodo (por fecha de la consulta medica) agrupadas por
 * estado efectivo, con los estados derivados NO_ASISTIO y NO_ATENDIDA.
 */
class EstadisticaConsultaIT extends BaseIntegracionIT {

    private static final String RUTA = "/api/estadisticas/consultas";
    private static final String MARZO = "?desde=2026-03-01&hasta=2026-03-31";
    private static final int NUMEROS_POR_FECHA = 12;

    private long patron;
    private final List<Long> semanales = new ArrayList<>();
    private final Map<String, List<Long>> numerosPorFecha = new HashMap<>();
    private final Map<String, Integer> usados = new HashMap<>();

    @BeforeEach
    void crearPatron() {
        numerosPorFecha.clear();
        usados.clear();
        semanales.clear();
        patron = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, 1, DATE '2026-01-01', DATE '2099-12-31')"
                        + " RETURNING id_turno_semanal",
                Long.class, idMedico, idEspecialidad, idConsultorio, idFuncionario);
        for (int i = 1; i <= NUMEROS_POR_FECHA; i++) {
            int minutos = 8 * 60 + (i - 1) * 20;
            semanales.add(jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, patron, i, hora(minutos), hora(minutos + 20)));
        }
    }

    /** Devuelve un numero sin usar de esa fecha, creando el turno (ACTIVO) la primera vez. */
    private long numero(String fecha) {
        List<Long> numeros = numerosPorFecha.computeIfAbsent(fecha, f -> {
            long turno = jdbc.queryForObject(
                    "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha, estado)"
                            + " VALUES (?, ?, ?::date, 'ACTIVO') RETURNING id_turno",
                    Long.class, patron, idConsultorio, f);
            List<Long> ids = new ArrayList<>();
            for (int i = 1; i <= NUMEROS_POR_FECHA; i++) {
                int minutos = 8 * 60 + (i - 1) * 20;
                ids.add(jdbc.queryForObject(
                        "INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                                + " VALUES (?, ?, ?, ?::time, ?::time) RETURNING id_numero",
                        Long.class, turno, semanales.get(i - 1), i, hora(minutos), hora(minutos + 20)));
            }
            return ids;
        });
        int indice = usados.merge(fecha, 1, Integer::sum) - 1;
        return numeros.get(indice);
    }

    /** Crea una consulta en la fecha medica indicada; agendada_en queda fijo salvo que se indique otro. */
    private void consulta(String fecha, String estado, long socio) {
        consulta(fecha, estado, socio, "2026-02-01 10:00:00-03");
    }

    private void consulta(String fecha, String estado, long socio, String agendadaEn) {
        long numero = numero(fecha);
        switch (estado) {
            case "AGENDADA" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en)"
                            + " VALUES (?, ?, 'AGENDADA', ?::timestamptz)", socio, numero, agendadaEn);
            case "ATENDIDA", "NO_SE_PRESENTO" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en,"
                            + " resultado_registrado_por, fecha_resultado)"
                            + " VALUES (?, ?, ?, ?::timestamptz, ?, now())",
                    socio, numero, estado, agendadaEn, idMedico);
            case "CANCELADA_SOCIO" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por,"
                            + " cancelada_en) VALUES (?, ?, 'CANCELADA_SOCIO', ?::timestamptz, ?, now())",
                    socio, numero, agendadaEn, socio);
            case "CANCELADA_INSTITUCION" -> jdbc.update(
                    "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en, cancelada_por,"
                            + " cancelada_en, motivo_cancelacion) VALUES (?, ?, 'CANCELADA_INSTITUCION',"
                            + " ?::timestamptz, ?, now(), 'Medico ausente')",
                    socio, numero, agendadaEn, idFuncionario);
            default -> throw new IllegalArgumentException(estado);
        }
    }

    private void aviso(long socio, String fecha) {
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?::date)",
                socio, idFuncionario, fecha);
    }

    private JsonNode consultar(String token, String consulta) {
        Respuesta r = get(RUTA + consulta, token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    private JsonNode comoAdmin(String consulta) {
        return consultar(tokenEmpleado(ciAdmin), consulta);
    }

    private static void assertEstados(JsonNode json, long agendada, long atendida, long canceladaSocio,
            long canceladaInstitucion, long noAsistio, long noAtendida, long noSePresento) {
        JsonNode e = json.path("estados");
        assertEquals(7, e.size());
        assertEquals(agendada, e.path("AGENDADA").asLong());
        assertEquals(atendida, e.path("ATENDIDA").asLong());
        assertEquals(canceladaSocio, e.path("CANCELADA_SOCIO").asLong());
        assertEquals(canceladaInstitucion, e.path("CANCELADA_INSTITUCION").asLong());
        assertEquals(noAsistio, e.path("NO_ASISTIO").asLong());
        assertEquals(noAtendida, e.path("NO_ATENDIDA").asLong());
        assertEquals(noSePresento, e.path("NO_SE_PRESENTO").asLong());
        assertEquals(agendada + atendida + canceladaSocio + canceladaInstitucion + noAsistio
                + noAtendida + noSePresento, json.path("totalConsultas").asLong());
    }

    @Test
    void cuentaLosSieteEstadosIncluidosLosDerivadosDeUnaFechaPasada() {
        // Fecha ya terminada: AGENDADA sin aviso => NO_ASISTIO; con aviso y sin resultado => NO_ATENDIDA.
        consulta("2026-03-10", "AGENDADA", idSocio1);
        consulta("2026-03-10", "AGENDADA", idSocio2);
        consulta("2026-03-10", "AGENDADA", idSocio3);
        aviso(idSocio3, "2026-03-10");
        consulta("2026-03-10", "ATENDIDA", idSocio4);
        consulta("2026-03-11", "ATENDIDA", idSocio1);
        consulta("2026-03-11", "NO_SE_PRESENTO", idSocio2);
        consulta("2026-03-11", "CANCELADA_SOCIO", idSocio3);
        consulta("2026-03-11", "CANCELADA_INSTITUCION", idSocio4);
        // Un socio con dos consultas el mismo dia y un solo aviso: ambas son NO_ATENDIDA, sin duplicar filas.
        consulta("2026-03-12", "AGENDADA", idSocio4);
        consulta("2026-03-12", "AGENDADA", idSocio4);
        aviso(idSocio4, "2026-03-12");

        JsonNode json = comoAdmin(MARZO);

        assertEquals("2026-03-01", json.path("desde").asString());
        assertEquals("2026-03-31", json.path("hasta").asString());
        // AGENDADA 0 (todas las de marzo ya terminaron), NO_ASISTIO 2, NO_ATENDIDA 1 + 2.
        assertEstados(json, 0, 2, 1, 1, 2, 3, 1);
        assertEquals(10, json.path("totalConsultas").asLong());
        assertEquals(1, json.path("canceladasPorSocio").asLong());
        assertEquals(10.0, json.path("porcentajeCancelacion").asDouble(), 0.0001);
        assertEquals("10 %", json.path("porcentajeCancelacionTexto").asString());
    }

    @Test
    void elTotalCoincideConUnaConsultaIndependienteSinDuplicados() {
        consulta("2026-03-10", "AGENDADA", idSocio1);
        consulta("2026-03-10", "ATENDIDA", idSocio2);
        consulta("2026-03-11", "CANCELADA_SOCIO", idSocio3);
        consulta("2026-03-11", "AGENDADA", idSocio3);
        aviso(idSocio3, "2026-03-11");
        consulta("2026-03-12", "NO_SE_PRESENTO", idSocio4);

        JsonNode json = comoAdmin(MARZO);

        Long enBase = jdbc.queryForObject(
                "SELECT count(*) FROM consulta c JOIN numero n ON n.id_numero = c.id_numero"
                        + " JOIN turno t ON t.id_turno = n.id_turno"
                        + " WHERE t.fecha BETWEEN '2026-03-01' AND '2026-03-31'", Long.class);
        assertEquals(enBase, json.path("totalConsultas").asLong());
        long suma = 0;
        for (JsonNode cantidad : json.path("estados")) {
            suma += cantidad.asLong();
        }
        assertEquals(enBase, suma);
    }

    @Test
    void agendadaHoyOEnElFuturoNoSeDerivaPeroAyerSi() {
        LocalDate hoy = LocalDate.now(ZONA);
        String ayer = hoy.minusDays(1).toString();
        // Fechas ya reservadas y el dia de hoy todavia no termino aunque haya aviso de llegada.
        consulta(hoy.toString(), "AGENDADA", idSocio1);
        consulta(hoy.toString(), "AGENDADA", idSocio2);
        aviso(idSocio2, hoy.toString());
        consulta(hoy.plusDays(3).toString(), "AGENDADA", idSocio3);
        consulta(ayer, "AGENDADA", idSocio4);

        JsonNode desdeHoy = comoAdmin("?desde=" + hoy + "&hasta=" + hoy.plusDays(7));
        assertEstados(desdeHoy, 3, 0, 0, 0, 0, 0, 0);

        JsonNode soloAyer = comoAdmin("?desde=" + ayer + "&hasta=" + ayer);
        assertEstados(soloAyer, 0, 0, 0, 0, 1, 0, 0);
    }

    @Test
    void elPeriodoSeAplicaALaFechaDeLaConsultaYNoALaFechaEnQueSeAgendo() {
        // Agendada en febrero para una fecha de marzo: cuenta en marzo.
        consulta("2026-03-15", "ATENDIDA", idSocio1, "2026-02-01 10:00:00-03");
        // Agendada en marzo para una fecha de abril: no cuenta en marzo.
        consulta("2026-04-15", "ATENDIDA", idSocio2, "2026-03-20 10:00:00-03");

        assertEstados(comoAdmin(MARZO), 0, 1, 0, 0, 0, 0, 0);
        assertEstados(comoAdmin("?desde=2026-04-01&hasta=2026-04-30"), 0, 1, 0, 0, 0, 0, 0);
    }

    @Test
    void losLimitesDelPeriodoSonInclusivos() {
        consulta("2026-02-28", "ATENDIDA", idSocio1);
        consulta("2026-03-01", "ATENDIDA", idSocio2);
        consulta("2026-03-31", "ATENDIDA", idSocio3);
        consulta("2026-04-01", "ATENDIDA", idSocio4);

        assertEstados(comoAdmin(MARZO), 0, 2, 0, 0, 0, 0, 0);
        assertEstados(comoAdmin("?desde=2026-03-01&hasta=2026-03-01"), 0, 1, 0, 0, 0, 0, 0);
        assertEstados(comoAdmin("?desde=2026-03-31&hasta=2026-03-31"), 0, 1, 0, 0, 0, 0, 0);
    }

    @Test
    void periodoVacioDevuelveSieteEstadosEnCeroYSinDatos() {
        consulta("2026-03-10", "ATENDIDA", idSocio1);

        JsonNode json = comoAdmin("?desde=2026-05-01&hasta=2026-05-31");

        assertEstados(json, 0, 0, 0, 0, 0, 0, 0);
        assertEquals(0, json.path("canceladasPorSocio").asLong());
        assertTrue(json.path("porcentajeCancelacion").isNull());
        assertEquals("Sin datos", json.path("porcentajeCancelacionTexto").asString());
    }

    @Test
    void porcentajeCeroParcialYCienPorCiento() {
        consulta("2026-03-10", "ATENDIDA", idSocio1);
        consulta("2026-03-10", "CANCELADA_INSTITUCION", idSocio2);
        JsonNode cero = comoAdmin("?desde=2026-03-10&hasta=2026-03-10");
        assertEquals("0 %", cero.path("porcentajeCancelacionTexto").asString());
        assertEquals(0.0, cero.path("porcentajeCancelacion").asDouble(), 0.0001);

        consulta("2026-03-20", "CANCELADA_SOCIO", idSocio1);
        consulta("2026-03-20", "ATENDIDA", idSocio2);
        consulta("2026-03-20", "ATENDIDA", idSocio3);
        JsonNode parcial = comoAdmin("?desde=2026-03-20&hasta=2026-03-20");
        assertEquals("33.33 %", parcial.path("porcentajeCancelacionTexto").asString());

        consulta("2026-03-25", "CANCELADA_SOCIO", idSocio4);
        JsonNode todas = comoAdmin("?desde=2026-03-25&hasta=2026-03-25");
        assertEquals("100 %", todas.path("porcentajeCancelacionTexto").asString());
        assertEquals(100.0, todas.path("porcentajeCancelacion").asDouble(), 0.0001);
    }

    @Test
    void sinParametrosUsaElMesEnCursoEnMontevideo() {
        LocalDate hoy = LocalDate.now(ZONA);
        JsonNode json = comoAdmin("");

        assertEquals(hoy.withDayOfMonth(1).toString(), json.path("desde").asString());
        assertEquals(hoy.withDayOfMonth(hoy.lengthOfMonth()).toString(), json.path("hasta").asString());
    }

    @Test
    void respuestaSinDatosDePacientes() {
        consulta("2026-03-10", "ATENDIDA", idSocio1);
        String cuerpo = get(RUTA + MARZO, tokenEmpleado(ciAdmin)).cuerpo();

        assertTrue(!cuerpo.contains(ciSocio1) && !cuerpo.contains("afeccion") && !cuerpo.contains("socio"),
                cuerpo);
    }

    @Test
    void fechasInvalidasDevuelven400ConCodigoValidacion() {
        String admin = tokenEmpleado(ciAdmin);
        for (String consulta : List.of("?desde=ayer", "?hasta=2026-13-01", "?desde=2026-02-30",
                "?desde=2026-03-31&hasta=2026-03-01", "?desde=01/03/2026")) {
            Respuesta r = get(RUTA + consulta, admin);
            assertEquals(400, r.estado(), consulta);
            assertEquals("VALIDACION", r.codigo(), consulta);
        }
    }

    @Test
    void inyeccionSqlEnLosParametrosSeRechazaYNoAfectaLaBase() {
        consulta("2026-03-10", "ATENDIDA", idSocio1);
        Long antes = jdbc.queryForObject("SELECT count(*) FROM consulta", Long.class);

        Respuesta r = get(RUTA + "?desde=2026-03-01'%3B%20DROP%20TABLE%20consulta%3B--",
                tokenEmpleado(ciAdmin));

        assertEquals(400, r.estado());
        assertEquals("VALIDACION", r.codigo());
        assertEquals(antes, jdbc.queryForObject("SELECT count(*) FROM consulta", Long.class));
    }

    @Test
    void soloElAdministradorAccede() {
        assertEquals(401, get(RUTA, null).estado());
        assertEquals(403, get(RUTA, tokenSocio(ciSocio1)).estado());
        assertEquals(403, get(RUTA, tokenEmpleado(ciFuncionario)).estado());
        assertEquals(403, get(RUTA, tokenEmpleado(ciMedico)).estado());
        assertEquals(200, get(RUTA, tokenEmpleado(ciAdmin)).estado());
    }

    @Test
    void administradorInactivadoPierdeAccesoConSuJwtAnterior() {
        String admin = tokenEmpleado(ciAdmin);
        assertEquals(200, get(RUTA, admin).estado());

        jdbc.update("UPDATE cuenta SET habilitada = FALSE, ultimo_inactivador = ?,"
                + " ultima_inactivacion_en = CURRENT_TIMESTAMP WHERE id_cuenta = ?", idAdmin, idAdmin);

        assertEquals(401, get(RUTA, admin).estado());
    }
}
