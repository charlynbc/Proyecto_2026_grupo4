package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/**
 * Campo cancelable de la consulta del socio (JSON real, PostgreSQL real): GET lista, GET detalle, POST y
 * consultas de hoy. El reloj de la aplicacion se fija a las 07:00 de hoy (Montevideo), asi que el resultado es el
 * mismo a cualquier hora del dia real: las consultas de hoy se siembran a horas absolutas (07:30 empieza en 30
 * minutos y 10:20 en 200) y los demas horarios estan lejos del borde de las 2 horas. Los ids de consulta (501 y
 * siguientes) y de aviso (801 y siguientes) no se parecen a los de los socios, para que un JOIN o un mapeo
 * equivocado no pase por coincidencia.
 */
class ConsultasCancelableIT extends BaseIntegracionIT {

    private static final LocalTime HORA_DEL_RELOJ = LocalTime.of(7, 0);

    /** Empieza 30 minutos despues del reloj fijo: dentro del plazo de 2 horas. */
    private static final LocalTime EN_30_MINUTOS = LocalTime.of(7, 30);

    /** Empieza 200 minutos despues del reloj fijo: fuera del plazo de 2 horas. */
    private static final LocalTime EN_200_MINUTOS = LocalTime.of(10, 20);

    /** Se restaura sola al terminar cada test (BaseIntegracionIT). */
    @BeforeEach
    void fijarElReloj() {
        reloj.fijar(hoy().atTime(HORA_DEL_RELOJ));
    }

    private void separarIds() {
        jdbc.queryForObject("SELECT setval(pg_get_serial_sequence('consulta', 'id_consulta'), 500)", Long.class);
        jdbc.queryForObject(
                "SELECT setval(pg_get_serial_sequence('aviso_llegada', 'id_aviso_llegada'), 800)", Long.class);
    }

    private long avisoDeLlegada(long socio, LocalDate fecha) {
        return jdbc.queryForObject(
                "INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)"
                        + " RETURNING id_aviso_llegada",
                Long.class, socio, idFuncionario, fecha);
    }

    /** Numero de hoy que empieza a la hora indicada (hora absoluta, no relativa a la hora real). */
    private long numeroDeHoyA(LocalTime inicio) {
        long turno = sembrarTurno(hoy(), 0);
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

    private static JsonNode item(JsonNode items, long id) {
        for (JsonNode item : items) {
            if (item.path("id").asLong() == id) return item;
        }
        throw new AssertionError("No esta la consulta " + id + " en " + items);
    }

    private static void cancelable(boolean esperado, JsonNode consulta, String motivo) {
        assertTrue(consulta.has("cancelable"), "El campo cancelable debe estar siempre: " + motivo);
        assertTrue(consulta.get("cancelable").isBoolean(), "cancelable debe ser booleano: " + motivo);
        assertEquals(esperado, consulta.get("cancelable").asBoolean(), motivo);
    }

    @Test
    void listaYDetalleTraenCancelableSegunLlegadaPlazoYSocio() {
        separarIds();
        long c1 = sembrarConsulta(idSocio1, numeroId(sembrarTurno(hoy().plusDays(1), 1), 1));
        long turnoConLlegada = sembrarTurno(hoy().plusDays(2), 2);
        long c2 = sembrarConsulta(idSocio1, numeroId(turnoConLlegada, 1));
        long c3 = sembrarConsulta(idSocio1, numeroId(turnoConLlegada, 2));
        long c4 = sembrarConsulta(idSocio1, numeroDeHoyA(EN_30_MINUTOS));
        long turnoCompartido = sembrarTurno(hoy().plusDays(3), 2);
        long c6 = sembrarConsulta(idSocio1, numeroId(turnoCompartido, 1));
        long c5 = sembrarConsulta(idSocio2, numeroId(turnoCompartido, 2));
        long avisoSocio1 = avisoDeLlegada(idSocio1, hoy().plusDays(2));
        long avisoSocio2 = avisoDeLlegada(idSocio2, hoy().plusDays(3));

        Set<Long> ids = new HashSet<>(
                List.of(c1, c2, c3, c4, c5, c6, avisoSocio1, avisoSocio2, idSocio1, idSocio2));
        assertEquals(10, ids.size(), "Los ids de consulta, aviso y socio no deben coincidir entre si");
        assertNotEquals(c1, idSocio1, "El id de la consulta no debe parecerse al del socio");
        assertNotEquals(avisoSocio1, idSocio1, "El id del aviso no debe parecerse al del socio");

        String socio1 = tokenSocio(ciSocio1);
        Respuesta lista = get("/api/consultas?size=100", socio1);
        assertEquals(200, lista.estado(), lista.cuerpo());
        JsonNode items = lista.json().path("items");
        assertEquals(5, items.size(), "El socio 1 tiene 5 consultas");
        cancelable(true, item(items, c1), "lejana, sin llegada ese dia");
        cancelable(false, item(items, c2), "con llegada ese dia");
        cancelable(false, item(items, c3), "otra consulta del mismo socio el mismo dia de la llegada");
        cancelable(false, item(items, c4), "empieza en 30 minutos");
        cancelable(true, item(items, c6), "la llegada del socio 2 ese dia no le afecta");

        for (long id : new long[] {c1, c2, c3, c4, c6}) {
            Respuesta detalle = get("/api/consultas/" + id, socio1);
            assertEquals(200, detalle.estado(), detalle.cuerpo());
            cancelable(item(items, id).get("cancelable").asBoolean(), detalle.json(), "detalle de " + id);
        }

        String socio2 = tokenSocio(ciSocio2);
        JsonNode itemsSocio2 = get("/api/consultas?size=100", socio2).json().path("items");
        assertEquals(1, itemsSocio2.size());
        cancelable(false, item(itemsSocio2, c5), "el socio 2 si registro llegada ese dia");
        cancelable(false, get("/api/consultas/" + c5, socio2).json(), "detalle del socio 2");
    }

    @Test
    void lasConsultasPasadasNoSonCancelablesNiConNiSinLlegada() {
        separarIds();
        long sinLlegada = sembrarConsulta(idSocio1, numeroId(sembrarTurno(hoy().minusDays(2), 1), 1));
        long conLlegada = sembrarConsulta(idSocio1, numeroId(sembrarTurno(hoy().minusDays(1), 1), 1));
        avisoDeLlegada(idSocio1, hoy().minusDays(1));

        JsonNode items = get("/api/consultas?size=100", tokenSocio(ciSocio1)).json().path("items");

        assertEquals("NO_ASISTIO", item(items, sinLlegada).path("estado").asString());
        cancelable(false, item(items, sinLlegada), "NO_ASISTIO");
        assertEquals("NO_ATENDIDA", item(items, conLlegada).path("estado").asString());
        cancelable(false, item(items, conLlegada), "NO_ATENDIDA");
    }

    @Test
    void laRespuestaDeAgendarTraeCancelableConLaLlegadaDelSocioEseDia() {
        separarIds();
        long turnoManana = sembrarTurno(hoy().plusDays(1), 1);
        long turnoDia4 = sembrarTurno(hoy().plusDays(4), 2);
        avisoDeLlegada(idSocio2, hoy().plusDays(4));

        Respuesta sinLlegada = post("/api/consultas", tokenSocio(ciSocio1),
                "{\"numeroId\":%d}".formatted(numeroId(turnoManana, 1)));
        assertEquals(201, sinLlegada.estado(), sinLlegada.cuerpo());
        cancelable(true, sinLlegada.json(), "agendada para manana, sin llegada");
        assertTrue(sinLlegada.json().path("id").asLong() > 500, "id de consulta esperado: 501 o mas");

        Respuesta conLlegada = post("/api/consultas", tokenSocio(ciSocio2),
                "{\"numeroId\":%d}".formatted(numeroId(turnoDia4, 1)));
        assertEquals(201, conLlegada.estado(), conLlegada.cuerpo());
        cancelable(false, conLlegada.json(), "el socio ya tiene llegada ese dia");

        Respuesta otroSocio = post("/api/consultas", tokenSocio(ciSocio3),
                "{\"numeroId\":%d}".formatted(numeroId(turnoDia4, 2)));
        assertEquals(201, otroSocio.estado(), otroSocio.cuerpo());
        cancelable(true, otroSocio.json(), "la llegada de otro socio ese dia no le afecta");
    }

    @Test
    void consultasDeHoyTraeCancelableFalseParaLaQueEmpiezaEn30MinutosAunConLlegada() {
        separarIds();
        long numero = numeroDeHoyA(EN_30_MINUTOS);
        long consulta = sembrarConsulta(idSocio1, numero);
        String funcionario = tokenEmpleado(ciFuncionario);

        Respuesta antes = get("/api/avisos-llegada/consultas-hoy?ci=" + ciSocio1, funcionario);
        assertEquals(200, antes.estado(), antes.cuerpo());
        assertEquals(consulta, antes.json().path("items").get(0).path("id").asLong());
        assertTrue(consulta > 500, "id de consulta esperado: 501 o mas");
        cancelable(false, antes.json().path("items").get(0), "empieza en 30 minutos");
        assertTrue(antes.json().get("llegada").isNull());

        Respuesta registro = post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));
        assertEquals(201, registro.estado(), registro.cuerpo());
        Respuesta despues = get("/api/avisos-llegada/consultas-hoy?ci=" + ciSocio1, funcionario);
        cancelable(false, despues.json().path("items").get(0), "con llegada");
        assertEquals(idFuncionario, despues.json().path("llegada").path("registradaPor").path("id").asLong());
    }

    @Test
    void consultasDeHoyDejaDeSerCancelableCuandoSeRegistraLaLlegada() {
        separarIds();
        long numero = numeroDeHoyA(EN_200_MINUTOS);
        long consulta = sembrarConsulta(idSocio2, numero);
        long otraDeSocio1 = sembrarConsulta(idSocio1, numeroId(sembrarTurno(hoy(), 1), 1));
        assertNotEquals(consulta, otraDeSocio1);
        String funcionario = tokenEmpleado(ciFuncionario);

        Respuesta antes = get("/api/avisos-llegada/consultas-hoy?ci=" + ciSocio2, funcionario);
        assertEquals(200, antes.estado(), antes.cuerpo());
        cancelable(true, antes.json().path("items").get(0), "faltan 200 minutos y no hay llegada");

        // La llegada de otro socio hoy no cambia nada.
        post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));
        cancelable(true, get("/api/avisos-llegada/consultas-hoy?ci=" + ciSocio2, funcionario)
                .json().path("items").get(0), "la llegada de otro socio no afecta");

        Respuesta registro = post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio2));
        assertEquals(201, registro.estado(), registro.cuerpo());
        JsonNode despues = get("/api/avisos-llegada/consultas-hoy?ci=" + ciSocio2, funcionario).json();
        cancelable(false, despues.path("items").get(0), "con llegada registrada hoy");
        assertEquals(1, despues.path("items").size());
        assertEquals(consulta, despues.path("items").get(0).path("id").asLong());
    }
}
