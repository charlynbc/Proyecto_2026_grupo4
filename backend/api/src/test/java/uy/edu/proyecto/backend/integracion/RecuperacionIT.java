package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

import org.junit.jupiter.api.Test;

/** RF-05 contra PostgreSQL real: recuperacion de contrasena. */
class RecuperacionIT extends BaseIntegracionIT {

    private static final String MENSAJE_PUBLICO =
            "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.";

    private Respuesta solicitar(String ci, String acceso) {
        return post("/api/auth/recuperacion/solicitar", null,
                "{\"ci\":\"" + ci + "\",\"acceso\":\"" + acceso + "\"}");
    }

    @Test
    void flujoCompletoRecuperaElAccesoYRevocaLasSesiones() {
        // El socio tenia una sesion iniciada antes de recuperar.
        Respuesta sesionPrevia = login(ciSocio1, "SOCIO");
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM sesion WHERE id_cuenta = ? AND revocada_en IS NULL",
                Integer.class, idSocio1));

        Respuesta solicitud = solicitar(ciSocio1, "SOCIO");
        assertEquals(202, solicitud.estado());
        assertEquals(MENSAJE_PUBLICO, solicitud.json().path("message").asString());

        var evento = capturaEnlaces.ultimaRecuperacion();
        assertNotNull(evento);
        assertEquals("u" + ciSocio1 + "@ejemplo.invalid", evento.correo());
        String hashGuardado = jdbc.queryForObject(
                "SELECT token_hash FROM enlace_cuenta"
                        + " WHERE id_cuenta = ? AND tipo = 'RECUPERACION'",
                String.class, idSocio1);
        assertFalse(hashGuardado.contains(evento.token()),
                "solo se guarda el hash del token");

        Respuesta completar = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"" + evento.token()
                        + "\",\"password\":\"Clave-Recuperada-1\"}");
        assertEquals(200, completar.estado(), completar.cuerpo());

        assertEquals(401, login(ciSocio1, CLAVE, "SOCIO").estado());
        assertEquals(200,
                login(ciSocio1, "Clave-Recuperada-1", "SOCIO").estado());

        // La sesion previa quedo revocada.
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM sesion WHERE id_cuenta = ? AND revocada_en IS NULL",
                Integer.class, idSocio1), "solo la sesion del nuevo login");
        Respuesta refreshViejo = enviar("POST", "/api/auth/refresh", null,
                sesionPrevia.refreshToken(), null);
        assertEquals(401, refreshViejo.estado());
    }

    @Test
    void respuestaEsIdenticaExistaONoLaCuenta() {
        Respuesta existente = solicitar(ciSocio1, "SOCIO");
        Respuesta inexistente = solicitar(ci(3999999), "SOCIO");
        Respuesta accesoCruzado = solicitar(ciSocio1, "EMPLEADO");

        for (Respuesta r : new Respuesta[]{existente, inexistente, accesoCruzado}) {
            assertEquals(202, r.estado());
            assertEquals(MENSAJE_PUBLICO, r.json().path("message").asString());
        }
        // Solo la cuenta existente y activa genero enlace.
        assertEquals(1, capturaEnlaces.cantidadRecuperaciones());
    }

    @Test
    void cuentaPendienteRecibeAvisoDePrimerIngresoSinEnlace() {
        Respuesta r = solicitar(ciSocioNuevo, "SOCIO");

        assertEquals(202, r.estado());
        assertEquals(MENSAJE_PUBLICO, r.json().path("message").asString());
        assertEquals(0, capturaEnlaces.cantidadRecuperaciones());
        assertEquals(1, capturaEnlaces.cantidadAvisosCuentaPendiente());
        assertEquals(0, contar("enlace_cuenta"));
    }

    @Test
    void cuentaInactivaNoGeneraEnlacePeroRespondeIgual() {
        jdbc.update("UPDATE cuenta SET habilitada = FALSE,"
                + " ultimo_inactivador = ?, ultima_inactivacion_en = CURRENT_TIMESTAMP"
                + " WHERE id_cuenta = ?", idAdmin, idSocio1);

        Respuesta r = solicitar(ciSocio1, "SOCIO");

        assertEquals(202, r.estado());
        assertEquals(MENSAJE_PUBLICO, r.json().path("message").asString());
        assertEquals(0, capturaEnlaces.cantidadRecuperaciones());
        assertEquals(0, contar("enlace_cuenta"));
    }

    @Test
    void enlaceUsadoOVencidoNoSirveYNoRevelaElMotivo() {
        solicitar(ciSocio1, "SOCIO");
        String token = capturaEnlaces.ultimaRecuperacion().token();

        Respuesta primero = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"" + token + "\",\"password\":\"Clave-Recuperada-1\"}");
        assertEquals(200, primero.estado());

        Respuesta reuso = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"" + token + "\",\"password\":\"Otra-Clave-99\"}");
        assertEquals(400, reuso.estado());
        assertEquals("ENLACE_INVALIDO", reuso.codigo());

        // Vencido: mismo codigo y mensaje.
        solicitar(ciSocio2, "SOCIO");
        String token2 = capturaEnlaces.ultimaRecuperacion().token();
        // El CHECK ck_enlace_cuenta_vencimiento exige vence_en > creado_en:
        // para simular un enlace vencido se retroceden ambas marcas.
        jdbc.update("UPDATE enlace_cuenta SET creado_en = CURRENT_TIMESTAMP - interval '25 hours',"
                + " vence_en = CURRENT_TIMESTAMP - interval '1 hour'"
                + " WHERE id_cuenta = ? AND tipo = 'RECUPERACION'", idSocio2);
        Respuesta vencido = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"" + token2 + "\",\"password\":\"Otra-Clave-99\"}");
        assertEquals(400, vencido.estado());
        assertEquals("ENLACE_INVALIDO", vencido.codigo());
        assertEquals(reuso.json().path("message").asString(),
                vencido.json().path("message").asString());

        // Inexistente: mismo codigo y mensaje.
        Respuesta inventado = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"inventado\",\"password\":\"Otra-Clave-99\"}");
        assertEquals(400, inventado.estado());
        assertEquals("ENLACE_INVALIDO", inventado.codigo());
        assertEquals(reuso.json().path("message").asString(),
                inventado.json().path("message").asString());
    }

    @Test
    void solicitudRepetidaDentroDelMinutoNoEnviaOtroCorreo() {
        assertEquals(202, solicitar(ciSocio1, "SOCIO").estado());
        assertEquals(202, solicitar(ciSocio1, "SOCIO").estado());

        assertEquals(1, capturaEnlaces.cantidadRecuperaciones());
        assertEquals(1, contar("enlace_cuenta"));
    }

    @Test
    void solicitudPosteriorInvalidaElEnlaceAnterior() throws Exception {
        solicitar(ciSocio1, "SOCIO");
        String primerToken = capturaEnlaces.ultimaRecuperacion().token();

        // Simula que paso mas de un minuto entre solicitudes.
        jdbc.update("UPDATE enlace_cuenta SET creado_en = CURRENT_TIMESTAMP - interval '2 minutes'"
                + " WHERE id_cuenta = ? AND tipo = 'RECUPERACION'", idSocio1);

        assertEquals(202, solicitar(ciSocio1, "SOCIO").estado());
        assertEquals(2, capturaEnlaces.cantidadRecuperaciones());
        String segundoToken = capturaEnlaces.ultimaRecuperacion().token();

        Respuesta viejo = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"" + primerToken + "\",\"password\":\"Clave-Uno-123\"}");
        assertEquals(400, viejo.estado());
        assertEquals("ENLACE_INVALIDO", viejo.codigo());

        Respuesta nuevo = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"" + segundoToken + "\",\"password\":\"Clave-Dos-123\"}");
        assertEquals(200, nuevo.estado());
        assertEquals(200, login(ciSocio1, "Clave-Dos-123", "SOCIO").estado());
    }

    @Test
    void completarConDatosInvalidosNoConsumeElEnlace() {
        solicitar(ciSocio1, "SOCIO");
        String token = capturaEnlaces.ultimaRecuperacion().token();

        for (String cuerpo : new String[]{
                "{}",
                "{\"token\":\"" + token + "\"}",
                "{\"token\":\"" + token + "\",\"password\":\"corta\"}"
        }) {
            Respuesta r = post("/api/auth/recuperacion/completar", null, cuerpo);
            assertEquals(400, r.estado(), cuerpo);
            assertEquals("VALIDACION", r.codigo(), cuerpo);
        }

        // El enlace sigue vigente: se puede completar despues de corregir.
        Respuesta ok = post("/api/auth/recuperacion/completar", null,
                "{\"token\":\"" + token + "\",\"password\":\"Clave-Buena-123\"}");
        assertEquals(200, ok.estado());
    }

    @Test
    void solicitarConDatosMalFormadosDevuelve400() {
        Respuesta sinCi = post("/api/auth/recuperacion/solicitar", null,
                "{\"acceso\":\"SOCIO\"}");
        assertEquals(400, sinCi.estado());
        assertEquals("VALIDACION", sinCi.codigo());

        Respuesta accesoInvalido = post("/api/auth/recuperacion/solicitar", null,
                "{\"ci\":\"" + ciSocio1 + "\",\"acceso\":\"OTRO\"}");
        assertEquals(400, accesoInvalido.estado());

        Respuesta ciInvalida = post("/api/auth/recuperacion/solicitar", null,
                "{\"ci\":\"123\",\"acceso\":\"SOCIO\"}");
        assertEquals(400, ciInvalida.estado());

        assertEquals(0, contar("enlace_cuenta"));
        assertNull(capturaEnlaces.ultimaRecuperacion());
    }
}
