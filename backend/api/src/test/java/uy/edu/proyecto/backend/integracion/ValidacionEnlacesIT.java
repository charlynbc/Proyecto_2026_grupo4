package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;

/** HTTP, seguridad y persistencia reales; correo capturado, PostgreSQL 17 aislado. */
class ValidacionEnlacesIT extends BaseIntegracionIT {

    private static final List<String> FLUJOS = List.of("primer-ingreso", "recuperacion");
    private static final String MENSAJE =
            "El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.";

    enum Invalido {
        INEXISTENTE, VENCIDO, USADO, REEMPLAZADO, CUENTA_INACTIVA,
        ESTADO_CUENTA_INCOMPATIBLE, TIPO_CRUZADO, CAMBIO_CORREO
    }

    static Stream<Arguments> invalidos() {
        return FLUJOS.stream().flatMap(flujo -> Arrays.stream(Invalido.values())
                .map(caso -> Arguments.of(flujo, caso)));
    }

    @ParameterizedTest
    @ValueSource(strings = {"primer-ingreso", "recuperacion"})
    void publicoRepetibleSinCambiosYLuegoSePuedeCompletar(String flujo) {
        if (flujo.equals("recuperacion")) {
            assertEquals(200, login(ciSocio1, "SOCIO").estado());
        }
        String token = solicitar(flujo);
        var antes = estado();
        int correos = capturaEnlaces.cantidad() + capturaEnlaces.cantidadRecuperaciones();

        for (int i = 0; i < 3; i++) {
            Respuesta respuesta = validar(flujo, token);
            assertEquals(200, respuesta.estado(), respuesta.cuerpo());
            assertEquals("", respuesta.cuerpo());
            assertTrue(respuesta.cabeceras().firstValue("cache-control")
                    .orElse("").contains("no-store"));
        }

        assertEquals(antes, estado(), "Validar no cambia enlace, cuenta ni sesiones");
        assertEquals(correos, capturaEnlaces.cantidad() + capturaEnlaces.cantidadRecuperaciones());
        assertEquals(200, completar(flujo, token).estado());
        assertInvalido(validar(flujo, token));
    }

    @ParameterizedTest
    @MethodSource("invalidos")
    void todosLosMotivosInvalidosTienenLaMismaRespuestaSinCambiarEstado(
            String flujo, Invalido caso
    ) {
        String token = solicitar(flujo);
        long idCuenta = cuenta(flujo);
        switch (caso) {
            case INEXISTENTE -> token = "x".repeat(43);
            case VENCIDO -> jdbc.update("""
                    UPDATE enlace_cuenta
                    SET creado_en = CURRENT_TIMESTAMP - interval '25 hours',
                        vence_en = CURRENT_TIMESTAMP - interval '1 hour'
                    WHERE id_cuenta = ?
                    """, idCuenta);
            case USADO -> assertEquals(200, completar(flujo, token).estado());
            case REEMPLAZADO -> {
                jdbc.update("UPDATE enlace_cuenta"
                        + " SET creado_en = CURRENT_TIMESTAMP - interval '2 minutes'"
                        + " WHERE id_cuenta = ?", idCuenta);
                solicitar(flujo);
            }
            case CUENTA_INACTIVA -> jdbc.update(
                    "UPDATE cuenta SET habilitada = FALSE WHERE id_cuenta = ?", idCuenta);
            case ESTADO_CUENTA_INCOMPATIBLE -> jdbc.update("""
                    UPDATE cuenta
                    SET primer_ingreso_completado = NOT primer_ingreso_completado,
                        direccion = 'Calle de prueba', contrasena_hash = ?
                    WHERE id_cuenta = ?
                    """, passwordEncoder.encode(CLAVE), idCuenta);
            case TIPO_CRUZADO -> token = solicitar(
                    flujo.equals("primer-ingreso") ? "recuperacion" : "primer-ingreso");
            case CAMBIO_CORREO -> jdbc.update("""
                    UPDATE enlace_cuenta SET tipo = 'CAMBIO_CORREO',
                        correo_nuevo = 'nuevo@ejemplo.invalid' WHERE id_cuenta = ?
                    """, idCuenta);
        }

        var antes = estado();
        Respuesta respuesta = validar(flujo, token);
        assertInvalido(respuesta);
        assertEquals(antes, estado());
        // El mismo token produce el mismo código y mensaje al completar.
        Respuesta completar = completar(flujo, token);
        assertInvalido(completar);
        assertEquals(respuesta.cuerpo(), completar.cuerpo());
    }

    @ParameterizedTest
    @ValueSource(strings = {"primer-ingreso", "recuperacion"})
    void cuerpoOTokenAusenteNuloOVacioEsEnlaceInvalido(String flujo) {
        String token = solicitar(flujo);
        var antes = estado();
        for (String cuerpo : new String[]{null, "null", "{}", "{\"token\":null}",
                "{\"token\":\"\"}", "{\"token\":\"   \"}"}) {
            assertInvalido(post(ruta(flujo, "validar"), null, cuerpo));
        }
        assertEquals(antes, estado());
        assertEquals(200, validar(flujo, token).estado());
    }

    @ParameterizedTest
    @ValueSource(strings = {"primer-ingreso", "recuperacion"})
    void laValidacionNoReservaElEnlaceFrenteAUnReemplazoPosterior(String flujo) {
        String anterior = solicitar(flujo);
        assertEquals(200, validar(flujo, anterior).estado());
        jdbc.update("UPDATE enlace_cuenta"
                + " SET creado_en = CURRENT_TIMESTAMP - interval '2 minutes'"
                + " WHERE id_cuenta = ?", cuenta(flujo));
        String nuevo = solicitar(flujo);

        assertInvalido(completar(flujo, anterior));
        assertEquals(200, validar(flujo, nuevo).estado());
        assertEquals(200, completar(flujo, nuevo).estado());
    }

    private String solicitar(String flujo) {
        String ci = flujo.equals("primer-ingreso") ? ciSocioNuevo : ciSocio1;
        Respuesta respuesta = post(ruta(flujo, "solicitar"), null,
                "{\"ci\":\"%s\",\"acceso\":\"SOCIO\"}".formatted(ci));
        assertEquals(202, respuesta.estado(), respuesta.cuerpo());
        return flujo.equals("primer-ingreso") ? capturaEnlaces.ultimo().token()
                : capturaEnlaces.ultimaRecuperacion().token();
    }

    private Respuesta validar(String flujo, String token) {
        return post(ruta(flujo, "validar"), null, "{\"token\":\"%s\"}".formatted(token));
    }

    private Respuesta completar(String flujo, String token) {
        return post(ruta(flujo, "completar"), null, """
                {"token":"%s","password":"Nueva-Clave-9",
                 "direccion":"Calle 1","telefono1":"099123456"}
                """.formatted(token));
    }

    private long cuenta(String flujo) {
        return flujo.equals("primer-ingreso") ? idSocioNuevo : idSocio1;
    }

    private String ruta(String flujo, String accion) {
        return "/api/auth/" + flujo + "/" + accion;
    }

    private Map<String, List<Map<String, Object>>> estado() {
        return Map.of(
                "enlaces", jdbc.queryForList("SELECT * FROM enlace_cuenta ORDER BY id_enlace"),
                "cuentas", jdbc.queryForList("SELECT * FROM cuenta ORDER BY id_cuenta"),
                "sesiones", jdbc.queryForList("SELECT * FROM sesion ORDER BY id_sesion"));
    }

    private void assertInvalido(Respuesta respuesta) {
        assertEquals(400, respuesta.estado(), respuesta.cuerpo());
        assertEquals("ENLACE_INVALIDO", respuesta.codigo());
        assertEquals(MENSAJE, respuesta.json().path("message").asString());
        assertEquals(2, respuesta.json().size(), "No expone datos de cuenta ni el motivo");
    }
}
