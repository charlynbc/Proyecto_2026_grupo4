package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import uy.edu.proyecto.backend.dispositivo.DispositivoRepository;

/** RNF-23: registro y baja de dispositivos push contra PostgreSQL real. */
class DispositivoPushIT extends BaseIntegracionIT {

    @Autowired
    DispositivoRepository dispositivos;

    /** La misma consulta que usa el despacho de avisos (TurnoFechasRepository). */
    private static final String CONSULTA_DEL_DESPACHO = """
            SELECT id_dispositivo
            FROM public.dispositivo_push
            WHERE id_socio = ? AND habilitado
            ORDER BY id_dispositivo
            """;

    private static String cuerpo(String token) {
        return "{\"token\":\"%s\"}".formatted(token);
    }

    private Respuesta registrar(String bearer, String token) {
        return post("/api/dispositivos", bearer, cuerpo(token));
    }

    private Respuesta darDeBaja(String bearer, String token) {
        return post("/api/dispositivos/baja", bearer, cuerpo(token));
    }

    private int filas(String token) {
        return jdbc.queryForObject(
                "SELECT count(*) FROM public.dispositivo_push WHERE token = ?",
                Integer.class, token);
    }

    private long socioDe(String token) {
        return jdbc.queryForObject(
                "SELECT id_socio FROM public.dispositivo_push WHERE token = ?",
                Long.class, token);
    }

    private boolean habilitado(String token) {
        return jdbc.queryForObject(
                "SELECT habilitado FROM public.dispositivo_push WHERE token = ?",
                Boolean.class, token);
    }

    private String registradoEn(String token) {
        return jdbc.queryForObject(
                "SELECT registrado_en::text FROM public.dispositivo_push WHERE token = ?",
                String.class, token);
    }

    private List<Long> vistosPorElDespacho(long socioId) {
        return jdbc.queryForList(CONSULTA_DEL_DESPACHO, Long.class, socioId);
    }

    @Test
    void registroNuevoDevuelve201YGuardaLaFilaDelSocio() {
        String socio1 = tokenSocio(ciSocio1);

        Respuesta r = registrar(socio1, "fcm-token-1");

        assertEquals(201, r.estado(), r.cuerpo());
        assertTrue(r.json().path("id").asLong() > 0);
        assertTrue(r.json().path("habilitado").asBoolean());
        assertFalse(r.json().path("registradoEn").asString().isBlank());
        assertEquals(1, filas("fcm-token-1"));
        assertEquals(idSocio1, socioDe("fcm-token-1"));
        assertTrue(habilitado("fcm-token-1"));
    }

    @Test
    void registroRepetidoDelMismoSocioDevuelve200SinCambiarRegistradoEn() {
        String socio1 = tokenSocio(ciSocio1);
        Respuesta primero = registrar(socio1, "fcm-token-1");
        String antes = registradoEn("fcm-token-1");

        Respuesta repetido = registrar(socio1, "fcm-token-1");

        assertEquals(200, repetido.estado(), repetido.cuerpo());
        assertEquals(primero.json().path("id").asLong(), repetido.json().path("id").asLong());
        assertTrue(repetido.json().path("habilitado").asBoolean());
        assertEquals(antes, registradoEn("fcm-token-1"));
        assertEquals(1, filas("fcm-token-1"));
    }

    @Test
    void tokenDeOtroSocioSeReasignaAlSocioAutenticado() {
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        Respuesta primero = registrar(socio1, "fcm-token-1");
        String antes = registradoEn("fcm-token-1");

        Respuesta reasignado = registrar(socio2, "fcm-token-1");

        assertEquals(200, reasignado.estado(), reasignado.cuerpo());
        assertEquals(primero.json().path("id").asLong(), reasignado.json().path("id").asLong());
        assertTrue(reasignado.json().path("habilitado").asBoolean());
        assertEquals(1, filas("fcm-token-1"));
        assertEquals(idSocio2, socioDe("fcm-token-1"));
        assertTrue(jdbc.queryForObject(
                "SELECT registrado_en > ?::timestamptz FROM public.dispositivo_push WHERE token = ?",
                Boolean.class, antes, "fcm-token-1"));
        assertEquals(List.of(), vistosPorElDespacho(idSocio1));
        assertEquals(1, vistosPorElDespacho(idSocio2).size());
    }

    @Test
    void dispositivoDeshabilitadoSeVuelveAHabilitar() {
        String socio1 = tokenSocio(ciSocio1);
        registrar(socio1, "fcm-token-1");
        assertEquals(204, darDeBaja(socio1, "fcm-token-1").estado());
        assertFalse(habilitado("fcm-token-1"));
        String antes = registradoEn("fcm-token-1");

        Respuesta r = registrar(socio1, "fcm-token-1");

        assertEquals(200, r.estado(), r.cuerpo());
        assertTrue(r.json().path("habilitado").asBoolean());
        assertTrue(habilitado("fcm-token-1"));
        assertEquals(1, filas("fcm-token-1"));
        assertTrue(jdbc.queryForObject(
                "SELECT registrado_en > ?::timestamptz FROM public.dispositivo_push WHERE token = ?",
                Boolean.class, antes, "fcm-token-1"));
    }

    @Test
    void elRegistroGuardaElTokenRecortado() {
        String socio1 = tokenSocio(ciSocio1);

        Respuesta r = registrar(socio1, "   fcm-token-1  ");

        assertEquals(201, r.estado(), r.cuerpo());
        assertEquals(1, filas("fcm-token-1"));
        assertEquals(0, filas("   fcm-token-1  "));
    }

    @Test
    void unTokenDe4096EntraYUnoDe4097Devuelve400SinGuardar() {
        String socio1 = tokenSocio(ciSocio1);

        assertEquals(201, registrar(socio1, "a".repeat(4096)).estado());
        Respuesta largo = registrar(socio1, "b".repeat(4097));

        assertEquals(400, largo.estado(), largo.cuerpo());
        assertEquals("VALIDACION", largo.codigo());
        assertEquals(1, contar("public.dispositivo_push"));
    }

    @Test
    void tokenVacioOSoloEspaciosDevuelve400SinGuardar() {
        String socio1 = tokenSocio(ciSocio1);

        for (String token : new String[] {"", "   "}) {
            Respuesta r = registrar(socio1, token);
            assertEquals(400, r.estado(), r.cuerpo());
            assertEquals("VALIDACION", r.codigo());
        }

        assertEquals(0, contar("public.dispositivo_push"));
    }

    @Test
    void sinCuerpoOConJsonRotoDevuelve400VALIDACION() {
        String socio1 = tokenSocio(ciSocio1);

        Respuesta sinCuerpo = post("/api/dispositivos", socio1, null);
        Respuesta roto = post("/api/dispositivos", socio1, "{\"token\":");
        Respuesta sinCampo = post("/api/dispositivos/baja", socio1, "{}");

        for (Respuesta r : List.of(sinCuerpo, roto, sinCampo)) {
            assertEquals(400, r.estado(), r.cuerpo());
            assertEquals("VALIDACION", r.codigo());
        }
        assertEquals(0, contar("public.dispositivo_push"));
    }

    @Test
    void laBajaDeshabilitaElDispositivoDelSocioYNoBorraLaFila() {
        String socio1 = tokenSocio(ciSocio1);
        registrar(socio1, "fcm-token-1");

        Respuesta r = darDeBaja(socio1, "fcm-token-1");

        assertEquals(204, r.estado(), r.cuerpo());
        assertTrue(r.cuerpo() == null || r.cuerpo().isEmpty());
        assertEquals(1, filas("fcm-token-1"));
        assertFalse(habilitado("fcm-token-1"));
    }

    @Test
    void laBajaDeUnTokenAjenoOInexistenteDa204YNoCambiaNada() {
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        registrar(socio1, "fcm-token-1");
        String antes = registradoEn("fcm-token-1");

        Respuesta ajeno = darDeBaja(socio2, "fcm-token-1");
        Respuesta inexistente = darDeBaja(socio2, "fcm-token-que-no-existe");

        assertEquals(204, ajeno.estado(), ajeno.cuerpo());
        assertEquals(204, inexistente.estado(), inexistente.cuerpo());
        assertTrue(habilitado("fcm-token-1"));
        assertEquals(idSocio1, socioDe("fcm-token-1"));
        assertEquals(antes, registradoEn("fcm-token-1"));
        assertEquals(0, filas("fcm-token-que-no-existe"));
        assertEquals(1, contar("public.dispositivo_push"));
    }

    @Test
    void despuesDeLaBajaElDespachoYaNoVeElDispositivo() {
        String socio1 = tokenSocio(ciSocio1);
        long id = registrar(socio1, "fcm-token-1").json().path("id").asLong();
        assertEquals(List.of(id), vistosPorElDespacho(idSocio1));

        darDeBaja(socio1, "fcm-token-1");

        assertEquals(List.of(), vistosPorElDespacho(idSocio1));
    }

    @Test
    void losEmpleadosRecibenElMismo403() {
        String funcionario = tokenEmpleado(ciFuncionario);

        assertEquals(403, registrar(funcionario, "fcm-token-1").estado());
        assertEquals(403, darDeBaja(funcionario, "fcm-token-1").estado());
        assertEquals(0, contar("public.dispositivo_push"));
    }

    @Test
    void deshabilitarPorTokenDeshabilitaSoloEseToken() {
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        registrar(socio1, "fcm-token-a");
        registrar(socio1, "fcm-token-b");
        registrar(socio2, "fcm-token-c");

        int filasTocadas = dispositivos.deshabilitarPorToken("fcm-token-a");

        assertEquals(1, filasTocadas);
        assertFalse(habilitado("fcm-token-a"));
        assertTrue(habilitado("fcm-token-b"), "otro token del mismo socio");
        assertTrue(habilitado("fcm-token-c"), "token de otro socio");
        assertEquals(1, vistosPorElDespacho(idSocio1).size());
        assertEquals(1, vistosPorElDespacho(idSocio2).size());
        assertEquals(socioDe("fcm-token-a"), idSocio1, "la fila no se borra ni se reasigna");
    }

    @Test
    void deshabilitarPorTokenNoPideElSocioYSirveParaElTokenDeCualquiera() {
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        registrar(socio1, "fcm-token-a");
        registrar(socio2, "fcm-token-c");

        assertEquals(1, dispositivos.deshabilitarPorToken("fcm-token-c"));

        assertFalse(habilitado("fcm-token-c"));
        assertTrue(habilitado("fcm-token-a"));
        assertEquals(0, vistosPorElDespacho(idSocio2).size());
    }

    @Test
    void deshabilitarPorTokenInexistenteNoFallaNiTocaNada() {
        registrar(tokenSocio(ciSocio1), "fcm-token-a");

        assertEquals(0, dispositivos.deshabilitarPorToken("fcm-token-que-no-existe"));

        assertTrue(habilitado("fcm-token-a"));
        assertEquals(1, filas("fcm-token-a"));
    }

    @Test
    void sinSesionDevuelve401() {
        assertEquals(401, registrar(null, "fcm-token-1").estado());
        assertEquals(401, darDeBaja(null, "fcm-token-1").estado());
    }
}
