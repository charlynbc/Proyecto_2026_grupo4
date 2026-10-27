package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
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

import tools.jackson.databind.JsonNode;

/**
 * RF-24 (registro de pases) y reserva con pase (RF-09) contra PostgreSQL real: emision durante la
 * atencion, vigencia, duplicados, consumo, no devolucion por inasistencia, atomicidad y concurrencia.
 */
class PasesRF24IT extends BaseIntegracionIT {

    private String medico;

    private long cardiologiaId() {
        return idEspecialidadConPase;
    }

    private Long segunda;

    private long segundaConPase() {
        if (segunda == null) {
            segunda = jdbc.queryForObject(
                    "INSERT INTO especialidad (nombre, requiere_pase) VALUES ('Neurologia', true)"
                            + " RETURNING id_especialidad", Long.class);
        }
        return segunda;
    }

    private String medico() {
        if (medico == null) {
            medico = tokenEmpleado(ciMedico);
        }
        return medico;
    }

    /** Consulta de hoy del socio, con aviso de llegada, lista para registrar su resultado. */
    private long consultaDeHoyConAviso(long socio) {
        long turno = sembrarTurno(hoy(), 1);
        long consulta = sembrarConsulta(socio, numeroId(turno, 1));
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)"
                + " ON CONFLICT DO NOTHING", socio, idFuncionario, hoy());
        return consulta;
    }

    private Respuesta atender(long consulta, String pasesJson) {
        return post("/api/medico/consultas/" + consulta + "/resultado", medico(),
                "{\"resultado\":\"ATENDIDA\",\"afeccion\":\"Control\",\"pases\":%s}".formatted(pasesJson));
    }

    private static String pase(long especialidad, Integer dias) {
        return dias == null
                ? "{\"especialidadDestinoId\":%d}".formatted(especialidad)
                : "{\"especialidadDestinoId\":%d,\"vigenciaDias\":%d}".formatted(especialidad, dias);
    }

    /** Pase ya emitido al socio (atencion previa), sembrado directamente en la base efimera. */
    private long paseEmitido(long socio, long especialidad, LocalDate venceEl) {
        long turno = sembrarTurno(hoy().minusDays(20 + contar("consulta")), 1);
        long consulta = sembrarConsulta(socio, numeroId(turno, 1));
        jdbc.update("UPDATE consulta SET estado = 'ATENDIDA', resultado_registrado_por = ?,"
                + " fecha_resultado = CURRENT_TIMESTAMP WHERE id_consulta = ?", idMedico, consulta);
        long atencion = jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion) VALUES (?, ?, 'Previa')"
                        + " RETURNING id_atencion", Long.class, consulta, idMedico);
        return jdbc.queryForObject(
                "INSERT INTO pase (id_atencion, id_especialidad_destino, emitido_en, vence_el)"
                        + " VALUES (?, ?, ?::date - 10, ?) RETURNING id_pase",
                Long.class, atencion, especialidad, venceEl, venceEl);
    }

    private long numeroEn(long especialidad, LocalDate fecha) {
        long turno = sembrarTurno(fecha, 1);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ? WHERE id_turno_semanal"
                + " = (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)", especialidad, turno);
        return numeroId(turno, 1);
    }

    private Respuesta reservar(String token, long numero, Long pase) {
        return post("/api/consultas", token, pase == null
                ? "{\"numeroId\":%d}".formatted(numero)
                : "{\"numeroId\":%d,\"paseId\":%d}".formatted(numero, pase));
    }

    private JsonNode disponibles(String token) {
        Respuesta r = get("/api/socios/me/pases/disponibles", token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    private int cantidadAtenciones() {
        return contar("atencion");
    }

    /* ---------- Emision (RF-24) ---------- */

    @Test
    void emiteDuranteLaAtencionConVigenciaPredeterminadaDe90Dias() {
        long consulta = consultaDeHoyConAviso(idSocio1);

        Respuesta r = atender(consulta, "[" + pase(cardiologiaId(), null) + "]");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("ATENDIDA", estadoConsulta(consulta));
        assertEquals(hoy().plusDays(90).toString(), r.json().path("pases").get(0).path("venceEl").asString());
        assertEquals(1, contar("pase"));
        JsonNode lista = disponibles(tokenSocio(ciSocio1));
        assertEquals(1, lista.size());
        assertEquals(cardiologiaId(), lista.get(0).path("especialidadDestino").path("id").asLong());
        assertEquals(0, disponibles(tokenSocio(ciSocio2)).size(), "El pase es solo del socio atendido");
    }

    @Test
    void vigenciaConfigurableEntre1Y365DiasYRechazoFueraDeRangoSinGuardarNada() {
        long neurologia = segundaConPase();
        long consulta = consultaDeHoyConAviso(idSocio1);

        for (String invalida : List.of("0", "366", "-5")) {
            Respuesta r = atender(consulta, "[" + pase(cardiologiaId(), Integer.valueOf(invalida)) + "]");
            assertEquals(400, r.estado(), "vigencia " + invalida);
            assertEquals("AGENDADA", estadoConsulta(consulta));
        }
        assertEquals(0, cantidadAtenciones());
        assertEquals(0, contar("pase"));

        Respuesta ok = atender(consulta,
                "[" + pase(cardiologiaId(), 1) + "," + pase(neurologia, 365) + "]");

        assertEquals(200, ok.estado(), ok.cuerpo());
        assertEquals(List.of(hoy().plusDays(1), hoy().plusDays(365)), List.of(
                LocalDate.parse(ok.json().path("pases").get(0).path("venceEl").asString()),
                LocalDate.parse(ok.json().path("pases").get(1).path("venceEl").asString())));
    }

    @Test
    void noRepiteLaEspecialidadEnUnMismoPedidoNiEmiteSinAvisoOFueraDeHoy() {
        long consulta = consultaDeHoyConAviso(idSocio1);

        Respuesta repetida = atender(consulta,
                "[" + pase(cardiologiaId(), null) + "," + pase(cardiologiaId(), 30) + "]");
        assertEquals(400, repetida.estado());
        assertEquals(0, contar("pase"));

        long futura = sembrarConsulta(idSocio2, numeroId(sembrarTurno(hoy().plusDays(3), 1), 1));
        Respuesta noEsDeHoy = atender(futura, "[" + pase(cardiologiaId(), null) + "]");
        assertEquals("CONSULTA_NO_ES_DE_HOY", noEsDeHoy.codigo());

        long sinAviso = sembrarConsulta(idSocio3, numeroId(sembrarTurno(hoy(), 1), 1));
        assertEquals("SIN_AVISO_LLEGADA", atender(sinAviso, "[" + pase(cardiologiaId(), null) + "]").codigo());
        assertEquals(0, contar("pase"));
        assertEquals(0, cantidadAtenciones());
    }

    @Test
    void rechazaElPaseDuplicadoSiYaHayUnoVigenteSinUsarYNoGuardaNada() {
        paseEmitido(idSocio1, cardiologiaId(), hoy().plusDays(30));
        long consulta = consultaDeHoyConAviso(idSocio1);
        int atencionesAntes = cantidadAtenciones();
        int pasesAntes = contar("pase");

        Respuesta r = atender(consulta, "[" + pase(cardiologiaId(), null) + "]");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("PASE_DUPLICADO", r.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta), "Atomicidad: la consulta sigue AGENDADA");
        assertEquals(atencionesAntes, cantidadAtenciones());
        assertEquals(pasesAntes, contar("pase"));
    }

    @Test
    void unPaseVencidoOYaUsadoNoImpideEmitirOtro() {
        long vencido = paseEmitido(idSocio1, cardiologiaId(), hoy().minusDays(1));
        long usado = paseEmitido(idSocio2, cardiologiaId(), hoy().plusDays(30));
        long destino = sembrarConsulta(idSocio2, numeroEn(cardiologiaId(), hoy().plusDays(2)));
        jdbc.update("UPDATE consulta SET id_pase = ?, estado = 'NO_SE_PRESENTO',"
                + " resultado_registrado_por = ?, fecha_resultado = CURRENT_TIMESTAMP"
                + " WHERE id_consulta = ?", usado, idMedico, destino);
        assertNotNull(vencido);

        assertEquals(200, atender(consultaDeHoyConAviso(idSocio1), "[" + pase(cardiologiaId(), null) + "]").estado());
        assertEquals(200, atender(consultaDeHoyConAviso(idSocio2), "[" + pase(cardiologiaId(), null) + "]").estado());
    }

    @Test
    void rechazaElPaseSiHayUnaConsultaPendienteEnEsaEspecialidadPeroNoSiFueInasistencia() {
        long pendiente = sembrarConsulta(idSocio1, numeroEn(cardiologiaId(), hoy().plusDays(4)));
        long consulta = consultaDeHoyConAviso(idSocio1);

        Respuesta r = atender(consulta, "[" + pase(cardiologiaId(), null) + "]");
        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("PASE_DUPLICADO", r.codigo());

        // Una AGENDADA de un dia ya terminado es NO_ASISTIO derivado: no cuenta como pendiente.
        jdbc.update("UPDATE turno SET fecha = ? WHERE id_turno = (SELECT n.id_turno FROM numero n"
                + " JOIN consulta c ON c.id_numero = n.id_numero WHERE c.id_consulta = ?)",
                hoy().minusDays(3), pendiente);
        assertEquals(200, atender(consulta, "[" + pase(cardiologiaId(), null) + "]").estado());
    }

    @Test
    void laAtencionNoSeRegistraSiElMedicoEsElSocioNiSiLaPideOtroMedicoNiUnSocio() {
        long consulta = consultaDeHoyConAviso(idSocio1);
        String cuerpo = "{\"resultado\":\"ATENDIDA\",\"afeccion\":\"X\",\"pases\":[]}";

        assertEquals(401, post("/api/medico/consultas/" + consulta + "/resultado", null, cuerpo).estado());
        assertEquals(403, post("/api/medico/consultas/" + consulta + "/resultado",
                tokenSocio(ciSocio1), cuerpo).estado());
        assertEquals(403, post("/api/medico/consultas/" + consulta + "/resultado",
                tokenEmpleado(ciFuncionario), cuerpo).estado());
        assertEquals("AGENDADA", estadoConsulta(consulta));
    }

    @Test
    void dosRegistrosSimultaneosDeLaMismaAtencionCreanUnaSolaAtencionYUnSoloPase() throws Exception {
        long consulta = consultaDeHoyConAviso(idSocio1);
        String pases = "[" + pase(cardiologiaId(), null) + "]";

        List<Respuesta> r = enParalelo(List.of(() -> atender(consulta, pases), () -> atender(consulta, pases)));

        assertEquals(1, r.stream().filter(x -> x.estado() == 200).count(), r.toString());
        assertTrue(r.stream().noneMatch(x -> x.estado() >= 500), r.toString());
        assertEquals(1, cantidadAtenciones());
        assertEquals(1, contar("pase"));
    }

    /* ---------- Reserva con pase (RF-09) ---------- */

    @Test
    void sinPaseOConPaseAjenoOdeOtraEspecialidadNoSeReserva() {
        long numero = numeroEn(cardiologiaId(), hoy().plusDays(5));
        long ajeno = paseEmitido(idSocio2, cardiologiaId(), hoy().plusDays(30));
        long otraEspecialidad = paseEmitido(idSocio1, segundaConPase(), hoy().plusDays(30));
        String socio = tokenSocio(ciSocio1);

        for (Long paseId : new Long[] {null, ajeno, otraEspecialidad, 999999L}) {
            Respuesta r = reservar(socio, numero, paseId);
            assertEquals(409, r.estado(), "paseId=" + paseId + " " + r.cuerpo());
            assertEquals("PASE_NO_VALIDO", r.codigo());
        }
    }

    @Test
    void laFechaMedicaDebeSerAnteriorOIgualAlVencimientoDelPase() {
        long pase = paseEmitido(idSocio1, cardiologiaId(), hoy().plusDays(5));
        String socio = tokenSocio(ciSocio1);

        Respuesta tarde = reservar(socio, numeroEn(cardiologiaId(), hoy().plusDays(6)), pase);
        assertEquals(409, tarde.estado());
        assertEquals("PASE_NO_VALIDO", tarde.codigo());

        Respuesta justo = reservar(socio, numeroEn(cardiologiaId(), hoy().plusDays(5)), pase);
        assertEquals(201, justo.estado(), justo.cuerpo());
    }

    @Test
    void reservarConsumeElPaseYNoPuedeReutilizarseNiSeDevuelveAlNoAsistir() {
        long pase = paseEmitido(idSocio1, cardiologiaId(), hoy().plusDays(30));
        String socio = tokenSocio(ciSocio1);
        assertEquals(1, disponibles(socio).size());

        Respuesta r = reservar(socio, numeroEn(cardiologiaId(), hoy().plusDays(5)), pase);

        assertEquals(201, r.estado(), r.cuerpo());
        long consulta = r.json().path("id").asLong();
        assertEquals(pase, jdbc.queryForObject(
                "SELECT id_pase FROM consulta WHERE id_consulta = ?", Long.class, consulta));
        assertEquals(0, disponibles(socio).size(), "Un pase usado deja de estar disponible");

        // La consulta pasa a ser una inasistencia (dia terminado): el pase NO se devuelve.
        jdbc.update("UPDATE turno SET fecha = ? WHERE id_turno = (SELECT n.id_turno FROM numero n"
                + " JOIN consulta c ON c.id_numero = n.id_numero WHERE c.id_consulta = ?)",
                hoy().minusDays(2), consulta);
        assertEquals(0, disponibles(socio).size());
        Respuesta otra = reservar(socio, numeroEn(cardiologiaId(), hoy().plusDays(6)), pase);
        assertEquals(409, otra.estado());
    }

    @Test
    void elEndpointDeDisponiblesSoloMuestraPasesPropiosVigentesYSinUsarConSeguridad() {
        long vigente = paseEmitido(idSocio1, cardiologiaId(), hoy().plusDays(10));
        paseEmitido(idSocio1, segundaConPase(), hoy().minusDays(1));
        paseEmitido(idSocio2, cardiologiaId(), hoy().plusDays(10));
        long hoyVence = paseEmitido(idSocio1, segundaConPase(), hoy());

        JsonNode lista = disponibles(tokenSocio(ciSocio1));

        assertEquals(List.of(hoyVence, vigente), ids(lista), "Orden por vencimiento; vence hoy sigue vigente");
        assertEquals(401, get("/api/socios/me/pases/disponibles", null).estado());
        assertEquals(403, get("/api/socios/me/pases/disponibles", tokenEmpleado(ciFuncionario)).estado());
    }

    @Test
    void dosReservasSimultaneasConElMismoPaseSoloConsumenUna() throws Exception {
        long pase = paseEmitido(idSocio1, cardiologiaId(), hoy().plusDays(30));
        String socio = tokenSocio(ciSocio1);
        long a = numeroEn(cardiologiaId(), hoy().plusDays(5));
        long b = numeroEn(cardiologiaId(), hoy().plusDays(6));

        List<Respuesta> r = enParalelo(List.of(() -> reservar(socio, a, pase), () -> reservar(socio, b, pase)));

        assertEquals(1, r.stream().filter(x -> x.estado() == 201).count(), r.toString());
        assertTrue(r.stream().noneMatch(x -> x.estado() >= 500), r.toString());
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_pase = ?", Integer.class, pase));
    }

    /* ---------- Utilidades ---------- */

    private static List<Long> ids(JsonNode lista) {
        List<Long> ids = new ArrayList<>();
        lista.forEach(p -> ids.add(p.path("id").asLong()));
        return ids;
    }

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
}
