package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** RF-06 contra PostgreSQL real: edicion de datos personales y cambio de correo. */
class DatosPersonalesIT extends BaseIntegracionIT {

    private String correoActual(long cuenta) {
        return jdbc.queryForObject(
                "SELECT correo FROM cuenta WHERE id_cuenta = ?",
                String.class, cuenta);
    }

    @Test
    void obtenerDevuelveLosDatosPropios() {
        String token = tokenSocio(ciSocio1);

        Respuesta r = get("/api/cuentas/me", token);

        assertEquals(200, r.estado());
        assertEquals(ciSocio1, r.json().path("ci").asString());
        assertEquals("Sofia", r.json().path("nombre").asString());
        assertEquals("Socia", r.json().path("apellido").asString());
        assertEquals("SOCIO", r.json().path("rol").asString());
        assertEquals("u" + ciSocio1 + "@ejemplo.invalid",
                r.json().path("correo").asString());
        assertTrue(r.json().path("correoPendiente").isNull());
    }

    @Test
    void actualizarDireccionYTelefonosAplicaDeInmediato() {
        String token = tokenSocio(ciSocio1);

        Respuesta r = enviar("PATCH", "/api/cuentas/me", token, null, """
                {"direccion":"Av. Italia 1234","telefono1":"099000111","telefono2":"24002233"}
                """);
        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("Av. Italia 1234", r.json().path("direccion").asString());
        assertEquals("099000111", r.json().path("telefono1").asString());
        assertEquals("24002233", r.json().path("telefono2").asString());

        var fila = jdbc.queryForMap(
                "SELECT direccion, telefono_1, telefono_2 FROM cuenta WHERE id_cuenta = ?",
                idSocio1);
        assertEquals("Av. Italia 1234", fila.get("direccion"));
        assertEquals("099000111", fila.get("telefono_1"));
        assertEquals("24002233", fila.get("telefono_2"));

        // telefono2 con "" se borra; los demas campos se conservan.
        Respuesta borrado = enviar("PATCH", "/api/cuentas/me", token, null,
                "{\"telefono2\":\"\"}");
        assertEquals(200, borrado.estado());
        assertTrue(borrado.json().path("telefono2").isNull());
        assertEquals("Av. Italia 1234",
                borrado.json().path("direccion").asString());
    }

    @Test
    void cambioDeCorreoSeAplicaSoloTrasConfirmarElEnlace() {
        String token = tokenSocio(ciSocio1);
        String correoOriginal = correoActual(idSocio1);

        Respuesta patch = enviar("PATCH", "/api/cuentas/me", token, null,
                "{\"correo\":\"nuevo-socio1@ejemplo.invalid\"}");
        assertEquals(200, patch.estado(), patch.cuerpo());
        assertEquals(correoOriginal, patch.json().path("correo").asString());
        assertEquals("nuevo-socio1@ejemplo.invalid",
                patch.json().path("correoPendiente").asString());
        assertEquals(correoOriginal, correoActual(idSocio1),
                "el correo no cambia hasta confirmar");

        var evento = capturaEnlaces.ultimoCambioCorreo();
        assertNotNull(evento);
        assertEquals("nuevo-socio1@ejemplo.invalid", evento.correoNuevo());
        String hashGuardado = jdbc.queryForObject(
                "SELECT token_hash FROM enlace_cuenta"
                        + " WHERE id_cuenta = ? AND tipo = 'CAMBIO_CORREO'",
                String.class, idSocio1);
        assertFalse(hashGuardado.contains(evento.token()),
                "solo se guarda el hash del token");

        Respuesta confirmacion = post("/api/auth/cambio-correo/confirmar", null,
                "{\"token\":\"" + evento.token() + "\"}");
        assertEquals(200, confirmacion.estado(), confirmacion.cuerpo());
        assertEquals("nuevo-socio1@ejemplo.invalid", correoActual(idSocio1));

        Respuesta reuso = post("/api/auth/cambio-correo/confirmar", null,
                "{\"token\":\"" + evento.token() + "\"}");
        assertEquals(400, reuso.estado());
        assertEquals("ENLACE_INVALIDO", reuso.codigo());

        Respuesta despues = get("/api/cuentas/me", token);
        assertEquals("nuevo-socio1@ejemplo.invalid",
                despues.json().path("correo").asString());
        assertTrue(despues.json().path("correoPendiente").isNull());
    }

    @Test
    void pedirOtroCambioDeCorreoInvalidaElEnlaceAnterior() {
        String token = tokenSocio(ciSocio1);

        enviar("PATCH", "/api/cuentas/me", token, null,
                "{\"correo\":\"primero@ejemplo.invalid\"}");
        String primerToken = capturaEnlaces.ultimoCambioCorreo().token();
        enviar("PATCH", "/api/cuentas/me", token, null,
                "{\"correo\":\"segundo@ejemplo.invalid\"}");
        String segundoToken = capturaEnlaces.ultimoCambioCorreo().token();

        Respuesta viejo = post("/api/auth/cambio-correo/confirmar", null,
                "{\"token\":\"" + primerToken + "\"}");
        assertEquals(400, viejo.estado());
        assertEquals("ENLACE_INVALIDO", viejo.codigo());

        Respuesta nuevo = post("/api/auth/cambio-correo/confirmar", null,
                "{\"token\":\"" + segundoToken + "\"}");
        assertEquals(200, nuevo.estado());
        assertEquals("segundo@ejemplo.invalid", correoActual(idSocio1));
    }

    @Test
    void enlaceVencidoNoAplicaElCambio() {
        String token = tokenSocio(ciSocio1);
        enviar("PATCH", "/api/cuentas/me", token, null,
                "{\"correo\":\"vencido@ejemplo.invalid\"}");
        String tokenCorreo = capturaEnlaces.ultimoCambioCorreo().token();
        // El CHECK ck_enlace_cuenta_vencimiento exige vence_en > creado_en:
        // para simular un enlace vencido se retroceden ambas marcas.
        jdbc.update("UPDATE enlace_cuenta SET creado_en = CURRENT_TIMESTAMP - interval '25 hours',"
                + " vence_en = CURRENT_TIMESTAMP - interval '1 hour'"
                + " WHERE id_cuenta = ? AND tipo = 'CAMBIO_CORREO'", idSocio1);

        Respuesta r = post("/api/auth/cambio-correo/confirmar", null,
                "{\"token\":\"" + tokenCorreo + "\"}");
        assertEquals(400, r.estado());
        assertEquals("ENLACE_INVALIDO", r.codigo());
        assertEquals("u" + ciSocio1 + "@ejemplo.invalid", correoActual(idSocio1));
    }

    @Test
    void camposProtegidosYValidacionesDevuelven400SinCambios() {
        String token = tokenSocio(ciSocio1);

        for (String cuerpo : new String[]{
                "{\"rol\":\"ADMINISTRADOR\"}",
                "{\"ci\":\"" + ciSocio2 + "\"}",
                "{\"nombre\":\"Otro\"}",
                "{\"correo\":\"sin-arroba\"}",
                "{\"telefono1\":\"\"}",
                "{}"
        }) {
            Respuesta r = enviar("PATCH", "/api/cuentas/me", token, null, cuerpo);
            assertEquals(400, r.estado(), cuerpo);
            assertEquals("VALIDACION", r.codigo(), cuerpo);
        }

        Respuesta r = get("/api/cuentas/me", token);
        assertEquals("Sofia", r.json().path("nombre").asString());
        assertEquals("SOCIO", r.json().path("rol").asString());
        assertEquals(0, capturaEnlaces.cantidadCambiosCorreo());
    }

    @Test
    void sinAutenticacionDevuelve401() {
        assertEquals(401, get("/api/cuentas/me", null).estado());
        Respuesta r = enviar("PATCH", "/api/cuentas/me", null, null,
                "{\"direccion\":\"X\"}");
        assertEquals(401, r.estado());
    }

    @Test
    void cuentaInactivaNoPuedeEditarNiConfirmar() {
        String token = tokenSocio(ciSocio1);
        enviar("PATCH", "/api/cuentas/me", token, null,
                "{\"correo\":\"pendiente@ejemplo.invalid\"}");
        String tokenCorreo = capturaEnlaces.ultimoCambioCorreo().token();

        jdbc.update("UPDATE cuenta SET habilitada = FALSE,"
                + " ultimo_inactivador = ?, ultima_inactivacion_en = CURRENT_TIMESTAMP"
                + " WHERE id_cuenta = ?", idAdmin, idSocio1);

        Respuesta edicion = enviar("PATCH", "/api/cuentas/me", token, null,
                "{\"direccion\":\"Otra 1\"}");
        assertEquals(401, edicion.estado());

        Respuesta confirmacion = post("/api/auth/cambio-correo/confirmar", null,
                "{\"token\":\"" + tokenCorreo + "\"}");
        assertEquals(400, confirmacion.estado());
        assertEquals("ENLACE_INVALIDO", confirmacion.codigo());
        assertEquals("u" + ciSocio1 + "@ejemplo.invalid", correoActual(idSocio1));
    }

    @Test
    void unUsuarioNoVeNiTocaLosDatosDeOtro() {
        String token1 = tokenSocio(ciSocio1);
        String token2 = tokenSocio(ciSocio2);

        enviar("PATCH", "/api/cuentas/me", token1, null,
                "{\"direccion\":\"Solo de socio 1\"}");

        Respuesta r = get("/api/cuentas/me", token2);
        assertEquals(ciSocio2, r.json().path("ci").asString());
        assertEquals("Calle Falsa 123", r.json().path("direccion").asString());
        assertTrue(jdbc.queryForList(
                "SELECT 1 FROM cuenta WHERE id_cuenta = ? AND direccion = 'Solo de socio 1'",
                idSocio2).isEmpty());
    }
}
