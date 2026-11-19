package uy.edu.proyecto.backend.integracion;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** GET /api/notificaciones por HTTP y PostgreSQL real: solo los avisos del socio del token. */
class NotificacionesListaIT extends BaseIntegracionIT {
    private long consultaDe(long socio) {
        long numero = numeroId(sembrarTurno(hoy().plusDays(5), 1), 1);
        return sembrarConsulta(socio, numero);
    }

    private long aviso(long consulta, String tipo, String creadaEn, String programadaPara) {
        return jdbc.queryForObject("""
                INSERT INTO notificacion (id_consulta, tipo, contenido, creada_en, programada_para)
                VALUES (?, ?, ?, ?::timestamptz, ?::timestamptz) RETURNING id_notificacion
                """, Long.class, consulta, tipo, "Cuerpo de " + tipo, creadaEn, programadaPara);
    }

    private List<Long> ids(Respuesta r) {
        List<Long> ids = new ArrayList<>();
        r.json().path("items").forEach(item -> ids.add(item.path("id").asLong()));
        return ids;
    }

    @Test
    void cadaSocioVeSoloSusAvisosYSuConteo() {
        long consulta1 = consultaDe(idSocio1);
        long consulta2 = consultaDe(idSocio2);
        long a1 = aviso(consulta1, "AGENDA", "2026-10-01T10:00:00Z", null);
        long a2 = aviso(consulta1, "CANCELACION", "2026-10-02T10:00:00Z", null);
        long b1 = aviso(consulta2, "AGENDA", "2026-10-03T10:00:00Z", null);

        Respuesta socio1 = get("/api/notificaciones", tokenSocio(ciSocio1));
        Respuesta socio2 = get("/api/notificaciones", tokenSocio(ciSocio2));

        assertEquals(200, socio1.estado(), socio1.cuerpo());
        assertEquals(List.of(a2, a1), ids(socio1));
        assertEquals(2, socio1.json().path("total").asInt());
        assertEquals(List.of(b1), ids(socio2));
        assertEquals(1, socio2.json().path("total").asInt());
        assertTrue(!socio1.cuerpo().contains("\"id\":" + b1), socio1.cuerpo());
    }

    @Test
    void unParametroDeSocioNoCambiaQuienPide() {
        long consulta1 = consultaDe(idSocio1);
        long consulta2 = consultaDe(idSocio2);
        long a1 = aviso(consulta1, "AGENDA", "2026-10-01T10:00:00Z", null);
        aviso(consulta2, "AGENDA", "2026-10-03T10:00:00Z", null);

        Respuesta r = get("/api/notificaciones?socioId=" + idSocio2 + "&idSocio=" + idSocio2,
                tokenSocio(ciSocio1));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(List.of(a1), ids(r));
        assertEquals(1, r.json().path("total").asInt());
    }

    @Test
    void ordenaDelMasNuevoAlMasViejoYDesempataPorIdDescendente() {
        long consulta = consultaDe(idSocio1);
        long viejo = aviso(consulta, "AGENDA", "2026-10-01T10:00:00Z", null);
        long igualA = aviso(consulta, "CANCELACION", "2026-10-02T10:00:00Z", null);
        long igualB = aviso(consulta, "SUSPENSION", "2026-10-02T10:00:00Z", null);
        long nuevo = aviso(consulta, "HISTORIA_ACTUALIZADA", "2026-10-03T10:00:00Z", null);

        Respuesta r = get("/api/notificaciones", tokenSocio(ciSocio1));

        assertEquals(List.of(nuevo, igualB, igualA, viejo), ids(r));
    }

    @Test
    void paginaConPageYSizeYElTotalEsElDeTodaLaLista() {
        long consulta = consultaDe(idSocio1);
        List<Long> creados = new ArrayList<>();
        for (int dia = 1; dia <= 5; dia++) {
            creados.add(aviso(consulta, "AGENDA", "2026-10-0" + dia + "T10:00:00Z", null));
        }
        String socio = tokenSocio(ciSocio1);

        Respuesta primera = get("/api/notificaciones?page=0&size=2", socio);
        Respuesta segunda = get("/api/notificaciones?page=1&size=2", socio);
        Respuesta tercera = get("/api/notificaciones?page=2&size=2", socio);
        Respuesta cuarta = get("/api/notificaciones?page=3&size=2", socio);

        assertEquals(List.of(creados.get(4), creados.get(3)), ids(primera));
        assertEquals(List.of(creados.get(2), creados.get(1)), ids(segunda));
        assertEquals(List.of(creados.get(0)), ids(tercera));
        assertEquals(List.of(), ids(cuarta));
        for (Respuesta r : List.of(primera, segunda, tercera, cuarta)) {
            assertEquals(5, r.json().path("total").asInt(), r.cuerpo());
            assertEquals(2, r.json().path("size").asInt());
        }
        assertEquals(2, tercera.json().path("page").asInt());
    }

    @Test
    void sinParametrosUsaPage0YSize20() {
        long consulta = consultaDe(idSocio1);
        for (int i = 0; i < 21; i++) {
            aviso(consulta, "AGENDA", "2026-10-01T10:" + (10 + i) + ":00Z", null);
        }

        Respuesta r = get("/api/notificaciones", tokenSocio(ciSocio1));

        assertEquals(20, r.json().path("items").size());
        assertEquals(0, r.json().path("page").asInt());
        assertEquals(20, r.json().path("size").asInt());
        assertEquals(21, r.json().path("total").asInt());
    }

    @Test
    void unRecordatorioFuturoNoSeListaNiSeCuentaHastaQueLlegaSuHora() {
        long consulta = consultaDe(idSocio1);
        long agenda = aviso(consulta, "AGENDA", "2026-10-01T10:00:00Z", null);
        long recordatorio = aviso(consulta, "RECORDATORIO", "2026-10-02T10:00:00Z", "2026-11-10T12:00:00Z");
        String socio = tokenSocio(ciSocio1);

        reloj.fijar(LocalDateTime.of(2026, 11, 10, 8, 0));
        Respuesta antes = get("/api/notificaciones", socio);

        assertEquals(List.of(agenda), ids(antes));
        assertEquals(1, antes.json().path("total").asInt());

        // A las 10:00 de Uruguay (13:00 UTC) ya paso la hora programada (12:00 UTC).
        reloj.fijar(LocalDateTime.of(2026, 11, 10, 10, 0));
        Respuesta despues = get("/api/notificaciones", socio);

        assertEquals(List.of(recordatorio, agenda), ids(despues));
        assertEquals(2, despues.json().path("total").asInt());
    }

    @Test
    void cadaAvisoLlevaTipoTituloContenidoFechaConDesfaseYConsulta() {
        long consulta = consultaDe(idSocio1);
        long id = aviso(consulta, "SUSPENSION", "2026-10-16T14:20:00Z", null);

        Respuesta r = get("/api/notificaciones", tokenSocio(ciSocio1));

        var item = r.json().path("items").get(0);
        assertEquals(id, item.path("id").asLong());
        assertEquals("SUSPENSION", item.path("tipo").asString());
        assertEquals("Turno suspendido", item.path("titulo").asString());
        assertEquals("Cuerpo de SUSPENSION", item.path("contenido").asString());
        assertEquals("2026-10-16T11:20:00-03:00", item.path("creadaEn").asString());
        assertEquals(consulta, item.path("consultaId").asLong());
        assertEquals(6, item.size());
    }

    @Test
    void elTituloSaleDelTipoDeCadaAviso() {
        long consulta = consultaDe(idSocio1);
        String[][] titulos = {
                {"AGENDA", "Consulta agendada"},
                {"CANCELACION", "Consulta cancelada"},
                {"SUSPENSION", "Turno suspendido"},
                {"HISTORIA_ACTUALIZADA", "Historia clínica actualizada"},
        };
        for (int i = 0; i < titulos.length; i++) {
            aviso(consulta, titulos[i][0], "2026-10-0" + (i + 1) + "T10:00:00Z", null);
        }
        aviso(consulta, "RECORDATORIO", "2026-10-05T10:00:00Z", "2026-10-06T10:00:00Z");

        Respuesta r = get("/api/notificaciones", tokenSocio(ciSocio1));

        List<String> recibidos = new ArrayList<>();
        r.json().path("items").forEach(item -> recibidos.add(item.path("tipo").asString() + "=" + item.path("titulo").asString()));
        assertEquals(List.of("RECORDATORIO=Recordatorio de consulta", "HISTORIA_ACTUALIZADA=Historia clínica actualizada",
                "SUSPENSION=Turno suspendido", "CANCELACION=Consulta cancelada", "AGENDA=Consulta agendada"), recibidos);
    }

    @Test
    void sinAvisosDevuelveListaVaciaYTotalCero() {
        Respuesta r = get("/api/notificaciones", tokenSocio(ciSocio1));

        assertEquals(200, r.estado(), r.cuerpo());
        assertTrue(r.json().path("items").isArray());
        assertEquals(0, r.json().path("items").size());
        assertEquals(0, r.json().path("total").asInt());
    }

    @Test
    void unSocioSinAvisosNoVeNiCuentaLosDeOtro() {
        aviso(consultaDe(idSocio1), "AGENDA", "2026-10-01T10:00:00Z", null);

        Respuesta r = get("/api/notificaciones", tokenSocio(ciSocio2));

        assertEquals(0, r.json().path("items").size());
        assertEquals(0, r.json().path("total").asInt());
    }

    @Test
    void parametrosInvalidosDan400ConValidacion() {
        String socio = tokenSocio(ciSocio1);
        String[][] casos = {
                {"size=0", "size debe estar entre 1 y 100"},
                {"size=101", "size debe estar entre 1 y 100"},
                {"size=abc", "size debe estar entre 1 y 100"},
                {"page=-1", "page debe ser un entero mayor o igual a 0"},
                {"page=abc", "page debe ser un entero mayor o igual a 0"},
        };
        for (String[] caso : casos) {
            Respuesta r = get("/api/notificaciones?" + caso[0], socio);
            assertEquals(400, r.estado(), caso[0] + " " + r.cuerpo());
            assertEquals("VALIDACION", r.codigo(), caso[0]);
            assertEquals(caso[1], r.json().path("message").asString(), caso[0]);
        }
    }

    @Test
    void sizeAdmiteElLimiteDeCien() {
        Respuesta r = get("/api/notificaciones?size=100", tokenSocio(ciSocio1));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(100, r.json().path("size").asInt());
    }

    @Test
    void sinTokenRecibe401() {
        Respuesta r = get("/api/notificaciones", null);

        assertEquals(401, r.estado(), r.cuerpo());
    }

    @Test
    void conOtroRolRecibe403() {
        aviso(consultaDe(idSocio1), "AGENDA", "2026-10-01T10:00:00Z", null);

        for (String ci : List.of(ciAdmin, ciFuncionario, ciMedico)) {
            Respuesta r = get("/api/notificaciones", tokenEmpleado(ci));
            assertEquals(403, r.estado(), ci + " " + r.cuerpo());
            assertTrue(!r.cuerpo().contains("Cuerpo de"), r.cuerpo());
        }
    }
}
