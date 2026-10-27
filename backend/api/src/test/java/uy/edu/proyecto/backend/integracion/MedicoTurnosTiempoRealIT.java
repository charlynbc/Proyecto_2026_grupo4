package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import tools.jackson.databind.JsonNode;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

/**
 * RF-21 contra PostgreSQL real: el médico consulta sus turnos y números y ve los cambios que hacen otros
 * actores (reserva, cancelación, llegada, resultado) mediante consultas periódicas, sin recarga manual.
 */
class MedicoTurnosTiempoRealIT extends BaseIntegracionIT {

    private static final long SONDEO_MS = 3000;

    private long turnoHoy;

    private void sembrarJornada() {
        turnoHoy = sembrarTurno(hoy(), 3);
    }

    private JsonNode numeros(String token) {
        Respuesta r = get("/api/medico/turnos/" + turnoHoy + "/numeros", token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json().path("items");
    }

    private JsonNode numero(String token, int n) {
        for (JsonNode item : numeros(token)) {
            if (item.path("numero").asInt() == n) {
                return item;
            }
        }
        throw new AssertionError("Sin el número " + n);
    }

    private long medicoAjeno() {
        String hash = jdbc.queryForObject(
                "SELECT contrasena_hash FROM cuenta WHERE id_cuenta = ?", String.class, idMedico);
        jdbc.update("INSERT INTO persona VALUES (?, 'Otro', 'Medico', DATE '1985-05-05')", ci(3456781));
        long id = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'MEDICO', 'ajeno@ejemplo.invalid',"
                        + " '099000333', 'Calle 2', ?, true) RETURNING id_cuenta",
                Long.class, ci(3456781), hash);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", id, idEspecialidad);
        return id;
    }

    @Test
    void sinTokenEsRechazadoYSoloElMedicoAccede() {
        sembrarJornada();
        String ruta = "/api/medico/turnos?fecha=" + hoy();

        assertEquals(401, get(ruta, null).estado());
        assertEquals(403, get(ruta, tokenSocio(ciSocio1)).estado());
        assertEquals(403, get(ruta, tokenEmpleado(ciFuncionario)).estado());
        assertEquals(403, get(ruta, tokenEmpleado(ciAdmin)).estado());
        assertEquals(200, get(ruta, tokenEmpleado(ciMedico)).estado());
        assertEquals(403, get("/api/medico/turnos/" + turnoHoy + "/numeros", tokenSocio(ciSocio1)).estado());
    }

    @Test
    void medicoInactivoPierdeAcceso() {
        sembrarJornada();
        String medico = tokenEmpleado(ciMedico);
        assertEquals(200, get("/api/medico/turnos?fecha=" + hoy(), medico).estado());

        jdbc.update("""
                UPDATE cuenta SET habilitada = FALSE, ultimo_inactivador = ?,
                       ultima_inactivacion_en = CURRENT_TIMESTAMP WHERE id_cuenta = ?
                """, idAdmin, idMedico);

        assertEquals(401, get("/api/medico/turnos?fecha=" + hoy(), medico).estado());
    }

    @Test
    void unMedicoAjenoNoVeTurnosNiNumerosDelOtro() {
        sembrarJornada();
        sembrarConsulta(idSocio1, numeroId(turnoHoy, 1));
        medicoAjeno();
        String ajeno = tokenEmpleado(ci(3456781));

        Respuesta propios = get("/api/medico/turnos?fecha=" + hoy(), ajeno);
        assertEquals(200, propios.estado(), propios.cuerpo());
        assertEquals(0, propios.json().path("items").size());

        Respuesta numeros = get("/api/medico/turnos/" + turnoHoy + "/numeros", ajeno);
        assertTrue(numeros.estado() == 403 || numeros.estado() == 404, "estado " + numeros.estado());
        assertFalse(numeros.cuerpo().contains(ciSocio1), "No debe filtrar datos del paciente");
    }

    @Test
    void fechaSinTurnosYTurnoSinReservasDevuelvenListasCoherentes() {
        String medico = tokenEmpleado(ciMedico);
        Respuesta vacia = get("/api/medico/turnos?fecha=" + hoy(), medico);
        assertEquals(200, vacia.estado());
        assertEquals(0, vacia.json().path("items").size());

        sembrarJornada();
        JsonNode turno = get("/api/medico/turnos?fecha=" + hoy(), medico).json().path("items").get(0);
        assertEquals(3, turno.path("cantidadNumeros").asInt());
        assertEquals(0, turno.path("cantidadReservados").asInt());
        for (JsonNode n : numeros(medico)) {
            assertTrue(n.path("consulta").isNull());
        }
        assertEquals(400, get("/api/medico/turnos?fecha=no-es-fecha", medico).estado());
    }

    @Test
    void elMedicoObservaReservaCancelacionLlegadaYResultadoSinRecargaManual() {
        sembrarJornada();
        String medico = tokenEmpleado(ciMedico);
        String funcionario = tokenEmpleado(ciFuncionario);

        long consulta = sembrarConsulta(idSocio1, numeroId(turnoHoy, 1));
        JsonNode reservado = numero(medico, 1);
        assertEquals(consulta, reservado.path("consulta").path("id").asLong());
        assertEquals(ciSocio1, reservado.path("consulta").path("paciente").path("ci").asString());
        assertTrue(reservado.path("consulta").path("llegadaEn").isNull());
        assertEquals(1, get("/api/medico/turnos?fecha=" + hoy(), medico)
                .json().path("items").get(0).path("cantidadReservados").asInt());

        post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));
        assertNotNull(numero(medico, 1).path("consulta").path("llegadaEn").asString());
        assertEquals(1, get("/api/medico/turnos/" + turnoHoy + "/numeros?llegada=true", medico)
                .json().path("items").size());
        assertEquals(0, get("/api/medico/turnos/" + turnoHoy + "/numeros?llegada=false", medico)
                .json().path("items").size());

        Respuesta resultado = post("/api/medico/consultas/" + consulta + "/resultado", medico,
                "{\"resultado\":\"NO_SE_PRESENTO\"}");
        assertEquals(200, resultado.estado(), resultado.cuerpo());
        assertEquals("NO_SE_PRESENTO", numero(medico, 1).path("consulta").path("estado").asString());

        long futuro = sembrarTurno(hoy().plusDays(3), 2);
        long otra = sembrarConsulta(idSocio2, numeroId(futuro, 1));
        String ruta = "/api/medico/turnos/" + futuro + "/numeros";
        assertEquals(otra, get(ruta, medico).json().path("items").get(0).path("consulta").path("id").asLong());
        assertEquals(200, post("/api/consultas/" + otra + "/cancelar", tokenSocio(ciSocio2), null).estado());
        JsonNode liberado = get(ruta, medico).json().path("items").get(0);
        assertTrue(liberado.path("disponible").asBoolean());
        assertTrue(liberado.path("consulta").isNull());
    }

    @Test
    void elOrdenYSentidoSeAplicanYSeConservanEntreSondeos() {
        sembrarJornada();
        String medico = tokenEmpleado(ciMedico);
        sembrarConsulta(idSocio1, numeroId(turnoHoy, 1));
        sembrarConsulta(idSocio2, numeroId(turnoHoy, 2));

        JsonNode asc = get("/api/medico/turnos/" + turnoHoy + "/numeros?orden=hora&sentido=asc", medico)
                .json().path("items");
        JsonNode desc = get("/api/medico/turnos/" + turnoHoy + "/numeros?orden=hora&sentido=desc", medico)
                .json().path("items");
        assertEquals(asc.get(0).path("numero").asInt(), desc.get(desc.size() - 1).path("numero").asInt());
        assertEquals(400, get("/api/medico/turnos/" + turnoHoy + "/numeros?orden=inventado", medico).estado());
    }

    @Test
    void dosClientesElMedicoConsultaCadaTresSegundosYDetectaLaLlegadaDelFuncionario() throws Exception {
        sembrarJornada();
        sembrarConsulta(idSocio1, numeroId(turnoHoy, 1));
        String medico = tokenEmpleado(ciMedico);
        String funcionario = tokenEmpleado(ciFuncionario);
        assertTrue(numero(medico, 1).path("consulta").path("llegadaEn").isNull());

        AtomicLong cambioMs = new AtomicLong();
        CompletableFuture<Void> clienteB = CompletableFuture.runAsync(() -> {
            try {
                Thread.sleep(1200);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
            Respuesta r = post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));
            assertEquals(201, r.estado(), r.cuerpo());
            cambioMs.set(System.nanoTime());
        });

        long detectadoNs = 0;
        int sondeos = 0;
        long limite = System.nanoTime() + Duration.ofSeconds(12).toNanos();
        while (System.nanoTime() < limite) {
            Thread.sleep(SONDEO_MS);
            sondeos++;
            if (!numero(medico, 1).path("consulta").path("llegadaEn").isNull()) {
                detectadoNs = System.nanoTime();
                break;
            }
        }
        clienteB.get();

        assertTrue(detectadoNs > 0, "El médico no detectó la llegada tras " + sondeos + " sondeos");
        long latenciaMs = Duration.ofNanos(detectadoNs - cambioMs.get()).toMillis();
        System.out.println("RF-21 latencia medida: " + latenciaMs + " ms con sondeo de " + SONDEO_MS + " ms");
        assertTrue(latenciaMs >= 0 && latenciaMs <= SONDEO_MS + 1000,
                "Latencia " + latenciaMs + " ms por encima del intervalo de sondeo");
    }
}
