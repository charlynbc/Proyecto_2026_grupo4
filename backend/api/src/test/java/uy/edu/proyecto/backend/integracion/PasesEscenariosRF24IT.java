package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.Map;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/**
 * RF-24: escenarios de cierre sobre el ciclo de vida del pase (reintento de atencion, inasistencias y
 * circuito completo atencion -> reserva -> cancelacion -> nueva reserva) contra PostgreSQL real.
 */
class PasesEscenariosRF24IT extends BaseIntegracionIT {

    private String medico() {
        return tokenEmpleado(ciMedico);
    }

    private long consultaDeHoyConAviso(long socio) {
        long turno = sembrarTurno(hoy(), 1);
        long consulta = sembrarConsulta(socio, numeroId(turno, 1));
        darAviso(socio, hoy());
        return consulta;
    }

    private void darAviso(long socio, LocalDate fecha) {
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)"
                + " ON CONFLICT DO NOTHING", socio, idFuncionario, fecha);
    }

    private Respuesta resultado(long consulta, String cuerpo) {
        return post("/api/medico/consultas/" + consulta + "/resultado", medico(), cuerpo);
    }

    private Respuesta atender(long consulta, Integer dias) {
        String pase = dias == null
                ? "{\"especialidadDestinoId\":%d}".formatted(idEspecialidadConPase)
                : "{\"especialidadDestinoId\":%d,\"vigenciaDias\":%d}".formatted(idEspecialidadConPase, dias);
        return resultado(consulta,
                "{\"resultado\":\"ATENDIDA\",\"afeccion\":\"Control\",\"pases\":[" + pase + "]}");
    }

    private long numeroConPase(LocalDate fecha) {
        long turno = sembrarTurno(fecha, 1);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ? WHERE id_turno_semanal"
                + " = (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)", idEspecialidadConPase, turno);
        return numeroId(turno, 1);
    }

    private Respuesta reservar(String token, long numero, long pase) {
        return post("/api/consultas", token, "{\"numeroId\":%d,\"paseId\":%d}".formatted(numero, pase));
    }

    private JsonNode disponibles(String token) {
        Respuesta r = get("/api/socios/me/pases/disponibles", token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    /** Pase ya consumido por una consulta del socio, sembrada con el dia y estado indicados. */
    private long[] paseConsumidoPorConsulta(long socio, LocalDate fecha) {
        long atendida = consultaDeHoyConAviso(socio);
        assertEquals(200, atender(atendida, 30).estado());
        long pase = jdbc.queryForObject("SELECT id_pase FROM pase", Long.class);
        long turno = sembrarTurno(fecha, 1);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ? WHERE id_turno_semanal"
                + " = (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)", idEspecialidadConPase, turno);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, id_pase) VALUES (?, ?, ?) RETURNING id_consulta",
                Long.class, socio, numeroId(turno, 1), pase);
        return new long[] {pase, consulta, numeroId(turno, 1)};
    }

    private String estadoEfectivo(String token, long consulta) {
        JsonNode raiz = get("/api/consultas", token).json();
        JsonNode lista = raiz.isArray() ? raiz : raiz.path("items");
        for (JsonNode c : lista) {
            if (c.path("id").asLong() == consulta) {
                return c.path("estado").asString();
            }
        }
        return "NO_ENCONTRADA";
    }

    /* ---------- A: atencion ya registrada ---------- */

    @Test
    void registrarDeNuevoUnaAtencionYaGuardadaSeRechazaSinCrearPasesNiModificarla() {
        long consulta = consultaDeHoyConAviso(idSocio1);
        assertEquals(200, atender(consulta, 30).estado());
        Map<String, Object> atencion = jdbc.queryForMap("SELECT * FROM atencion");
        Map<String, Object> pase = jdbc.queryForMap("SELECT * FROM pase");

        Respuesta repetido = atender(consulta, 60);
        Respuesta distinto = resultado(consulta,
                "{\"resultado\":\"ATENDIDA\",\"afeccion\":\"Otra\",\"pases\":[]}");

        assertEquals(409, repetido.estado(), repetido.cuerpo());
        assertEquals("CONSULTA_NO_AGENDADA", repetido.codigo());
        assertEquals(409, distinto.estado(), distinto.cuerpo());
        assertEquals(1, contar("atencion"));
        assertEquals(1, contar("pase"));
        assertEquals(atencion, jdbc.queryForMap("SELECT * FROM atencion"));
        assertEquals(pase, jdbc.queryForMap("SELECT * FROM pase"));
        assertEquals("ATENDIDA", estadoConsulta(consulta));
    }

    /* ---------- B: NO_SE_PRESENTO ---------- */

    @Test
    void noSePresentoDejaElPaseConsumidoYElNumeroOcupado() {
        long[] ids = paseConsumidoPorConsulta(idSocio1, hoy());
        long pase = ids[0];
        long consulta = ids[1];
        darAviso(idSocio1, hoy());

        Respuesta r = resultado(consulta, "{\"resultado\":\"NO_SE_PRESENTO\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("NO_SE_PRESENTO", estadoConsulta(consulta));
        assertEquals(pase, jdbc.queryForObject(
                "SELECT id_pase FROM consulta WHERE id_consulta = ?", Long.class, consulta));
        assertEquals(0, disponibles(tokenSocio(ciSocio1)).size(), "No vuelve al listado de disponibles");
        Respuesta otro = post("/api/consultas", tokenSocio(ciSocio2), "{\"numeroId\":%d}".formatted(ids[2]));
        assertEquals(409, otro.estado(), "El numero no se libera");
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_numero = ?", Integer.class, ids[2]));
        Respuesta reuso = reservar(tokenSocio(ciSocio1), numeroConPase(hoy().plusDays(6)), pase);
        assertEquals(409, reuso.estado());
        assertEquals(1, contar("pase"));
    }

    /* ---------- C: NO_ATENDIDA ---------- */

    @Test
    void unaConsultaConLlegadaSinAtencionEsNoAtendidaYNoLiberaElPase() {
        LocalDate ayer = hoy().minusDays(1);
        long[] ids = paseConsumidoPorConsulta(idSocio1, ayer);
        darAviso(idSocio1, ayer);
        String socio = tokenSocio(ciSocio1);

        assertEquals("NO_ATENDIDA", estadoEfectivo(socio, ids[1]));
        assertEquals("AGENDADA", estadoConsulta(ids[1]), "El estado persistido no se modifica");
        assertEquals(0, disponibles(socio).size());
        Respuesta reuso = reservar(socio, numeroConPase(hoy().plusDays(5)), ids[0]);
        assertEquals(409, reuso.estado(), reuso.cuerpo());
        assertEquals("PASE_NO_VALIDO", reuso.codigo());
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_pase = ?", Integer.class, ids[0]));
    }

    /* ---------- D: circuito completo ---------- */

    @Test
    void circuitoCompletoAtencionReservaCancelacionYNuevaReservaConservaElPaseOriginal() {
        long consulta = consultaDeHoyConAviso(idSocio1);
        assertEquals(200, atender(consulta, 45).estado());
        Map<String, Object> original = jdbc.queryForMap("SELECT * FROM pase");
        long pase = ((Number) original.get("id_pase")).longValue();
        String socio = tokenSocio(ciSocio1);

        JsonNode lista = disponibles(socio);
        assertEquals(1, lista.size());
        assertEquals(pase, lista.get(0).path("id").asLong());
        assertEquals(hoy().plusDays(45).toString(), lista.get(0).path("venceEl").asString());
        assertEquals(0, disponibles(tokenSocio(ciSocio2)).size());

        long primero = numeroConPase(hoy().plusDays(5));
        Respuesta ajeno = reservar(tokenSocio(ciSocio2), primero, pase);
        assertEquals(409, ajeno.estado());
        assertEquals("PASE_NO_VALIDO", ajeno.codigo());

        Respuesta reserva = reservar(socio, primero, pase);
        assertEquals(201, reserva.estado(), reserva.cuerpo());
        long reservaId = reserva.json().path("id").asLong();
        assertEquals(0, disponibles(socio).size(), "El pase queda consumido");

        Respuesta ajenaCancelar = post("/api/consultas/" + reservaId + "/cancelar", tokenSocio(ciSocio2), null);
        assertTrue(ajenaCancelar.estado() == 403 || ajenaCancelar.estado() == 404, ajenaCancelar.cuerpo());
        assertEquals(0, disponibles(socio).size());

        Respuesta cancelar = post("/api/consultas/" + reservaId + "/cancelar", socio, null);
        assertEquals(200, cancelar.estado(), cancelar.cuerpo());
        assertTrue(cancelar.json().path("paseDevuelto").asBoolean());
        JsonNode devuelto = disponibles(socio);
        assertEquals(1, devuelto.size());
        assertEquals(pase, devuelto.get(0).path("id").asLong(), "Mismo identificador");
        assertEquals(original, jdbc.queryForMap("SELECT * FROM pase"),
                "Emision y vencimiento originales intactos");
        assertEquals(1, contar("pase"));

        Respuesta segunda = reservar(socio, numeroConPase(hoy().plusDays(6)), pase);
        assertEquals(201, segunda.estado(), segunda.cuerpo());
        assertEquals(0, disponibles(socio).size());
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_pase = ?", Integer.class, pase));
        assertFalse(devuelto.get(0).path("venceEl").asString().isEmpty());
    }
}
