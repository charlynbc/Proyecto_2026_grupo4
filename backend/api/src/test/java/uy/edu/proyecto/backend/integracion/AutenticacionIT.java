package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;

/** RF-01 y RF-02 contra PostgreSQL real: login, refresh, logout y primer ingreso. */
class AutenticacionIT extends BaseIntegracionIT {

    @Autowired
    JwtEncoder jwtEncoder;

    private String tokenVencido(long cuenta, String rol) {
        Instant antes = Instant.now().minusSeconds(3600);
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer("grupo4-api")
                .subject(Long.toString(cuenta))
                .claim("role", rol)
                .issuedAt(antes)
                .expiresAt(antes.plusSeconds(900))
                .build();
        return jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    private int sesionesActivas(long cuenta) {
        return jdbc.queryForObject(
                "SELECT count(*) FROM sesion WHERE id_cuenta = ? AND revocada_en IS NULL",
                Integer.class, cuenta);
    }

    @Test
    void loginCorrectoEmiteTokenYCookieHttpOnlyConSesionPersistida() {
        Respuesta r = login(ciSocio1, "SOCIO");

        assertEquals(200, r.estado());
        assertEquals("SOCIO", r.json().path("role").asString());
        assertFalse(r.json().path("token").asString().isBlank());
        String cookie = r.refreshSetCookie();
        assertNotNull(cookie);
        assertTrue(cookie.contains("HttpOnly"));
        assertTrue(cookie.contains("Path=/api/auth"));
        assertTrue(r.refreshToken().startsWith("v2."));
        assertEquals(1, sesionesActivas(idSocio1));
        String hash = jdbc.queryForObject(
                "SELECT token_renovacion_hash FROM sesion WHERE id_cuenta = ?", String.class, idSocio1);
        assertFalse(hash.contains(r.refreshToken()), "El token no debe guardarse en claro");
    }

    @Test
    void loginIncorrectoNoCreaSesion() {
        assertEquals(401, login(ciSocio1, "otra-clave-x", "SOCIO").estado());
        assertEquals(401, login(ci(3999999), "SOCIO").estado());
        assertEquals(401, login(ciFuncionario, "SOCIO").estado());
        assertEquals(401, login(ciSocio1, "EMPLEADO").estado());
        assertEquals(0, contar("sesion"));
    }

    @Test
    void loginAntiguoConCedulaYClaveNoExiste() {
        Respuesta r = post("/api/auth/login", null,
                "{\"cedula\":\"%s\",\"clave\":\"%s\"}".formatted(ciSocio1, CLAVE));
        assertTrue(r.estado() == 400 || r.estado() == 401, "estado " + r.estado());
        assertEquals(0, contar("sesion"));
    }

    @Test
    void refreshPorCookieRotaElTokenYRevocaElAnterior() {
        Respuesta inicial = login(ciSocio1, "SOCIO");
        String viejo = inicial.refreshToken();

        Respuesta renovada = enviar("POST", "/api/auth/refresh", null, viejo, null);
        assertEquals(200, renovada.estado());
        String nuevo = renovada.refreshToken();
        assertNotNull(nuevo);
        assertNotEquals(viejo, nuevo);
        assertFalse(renovada.json().path("token").asString().isBlank());

        Respuesta reutilizado = enviar("POST", "/api/auth/refresh", null, viejo, null);
        assertEquals(401, reutilizado.estado());
        assertEquals("REFRESH_INVALIDO", reutilizado.codigo());

        assertEquals(200, enviar("POST", "/api/auth/refresh", null, nuevo, null).estado());
    }

    @Test
    void refreshSinCookieOConCookieInventadaEsRechazado() {
        Respuesta sin = enviar("POST", "/api/auth/refresh", null, null, null);
        assertEquals(401, sin.estado());
        assertEquals("REFRESH_FALTANTE", sin.codigo());

        Respuesta falsa = enviar("POST", "/api/auth/refresh", null, "v2.inventado", null);
        assertEquals(401, falsa.estado());
        assertEquals("REFRESH_INVALIDO", falsa.codigo());
    }

    @Test
    void refreshConBearerVencidoEsRechazadoPorElServidorYLaCookieSigueSiendoValida() {
        // Razon de ser de la correccion b7b73e6: el servidor rechaza un bearer vencido
        // incluso en /api/auth/refresh, por eso el cliente nunca debe enviarlo.
        Respuesta inicial = login(ciSocio1, "SOCIO");
        String vencido = tokenVencido(idSocio1, "SOCIO");

        Respuesta conBearer = enviar("POST", "/api/auth/refresh", vencido, inicial.refreshToken(), null);
        assertEquals(401, conBearer.estado());
        assertEquals(1, sesionesActivas(idSocio1));

        Respuesta sinBearer = enviar("POST", "/api/auth/refresh", null, inicial.refreshToken(), null);
        assertEquals(200, sinBearer.estado());
    }

    @Test
    void logoutConTokenValidoRevocaLaSesionYBorraLaCookie() {
        Respuesta inicial = login(ciSocio1, "SOCIO");
        String refresh = inicial.refreshToken();
        String acceso = inicial.json().path("token").asString();

        Respuesta r = enviar("POST", "/api/auth/logout", acceso, refresh, null);

        assertEquals(204, r.estado());
        String borrado = r.refreshSetCookie();
        assertNotNull(borrado);
        assertEquals("", r.refreshToken());
        assertTrue(borrado.contains("Max-Age=0"));
        assertEquals(0, sesionesActivas(idSocio1));
        assertNotNull(jdbc.queryForObject(
                "SELECT revocada_en FROM sesion WHERE id_cuenta = ?", java.sql.Timestamp.class, idSocio1));

        Respuesta tras = enviar("POST", "/api/auth/refresh", null, refresh, null);
        assertEquals(401, tras.estado());
        assertEquals("REFRESH_INVALIDO", tras.codigo());
    }

    @Test
    void logoutConAccessTokenVencidoSeRecuperaRenovandoSinBearerYReintentando() {
        Respuesta inicial = login(ciFuncionario, "EMPLEADO");
        String refresh = inicial.refreshToken();
        String vencido = tokenVencido(idFuncionario, "FUNCIONARIO");

        Respuesta rechazado = enviar("POST", "/api/auth/logout", vencido, refresh, null);
        assertEquals(401, rechazado.estado());
        assertEquals(1, sesionesActivas(idFuncionario), "Un logout rechazado no debe revocar nada");

        Respuesta renovada = enviar("POST", "/api/auth/refresh", null, refresh, null);
        assertEquals(200, renovada.estado());
        String accesoNuevo = renovada.json().path("token").asString();
        String refreshNuevo = renovada.refreshToken();

        Respuesta reintento = enviar("POST", "/api/auth/logout", accesoNuevo, refreshNuevo, null);
        assertEquals(204, reintento.estado());
        assertEquals("", reintento.refreshToken());
        assertEquals(0, sesionesActivas(idFuncionario));
        assertEquals(401, enviar("POST", "/api/auth/refresh", null, refreshNuevo, null).estado());
    }

    @Test
    void logoutNoRevocaLasSesionesDeOtroDispositivo() {
        String refreshA = login(ciSocio1, "SOCIO").refreshToken();
        Respuesta b = login(ciSocio1, "SOCIO");
        assertEquals(2, sesionesActivas(idSocio1));

        enviar("POST", "/api/auth/logout", b.json().path("token").asString(), b.refreshToken(), null);

        assertEquals(1, sesionesActivas(idSocio1));
        assertEquals(200, enviar("POST", "/api/auth/refresh", null, refreshA, null).estado());
    }

    @Test
    void logoutSinAutenticacionEsRechazado() {
        Respuesta inicial = login(ciSocio1, "SOCIO");
        assertEquals(401, enviar("POST", "/api/auth/logout", null, inicial.refreshToken(), null).estado());
        assertEquals(1, sesionesActivas(idSocio1));
    }

    @Test
    void refreshConSesionVencidaEnBaseEsRechazado() {
        Respuesta inicial = login(ciSocio1, "SOCIO");
        jdbc.update("UPDATE sesion SET creada_en = now() - interval '10 days',"
                + " vence_en = now() - interval '1 day' WHERE id_cuenta = ?", idSocio1);

        Respuesta r = enviar("POST", "/api/auth/refresh", null, inicial.refreshToken(), null);
        assertEquals(401, r.estado());
    }

    @Test
    void primerIngresoCompletoConEnlaceCapturadoYLuegoLogin() {
        Respuesta solicitud = post("/api/auth/primer-ingreso/solicitar", null,
                "{\"ci\":\"%s\",\"acceso\":\"SOCIO\"}".formatted(ciSocioNuevo));
        assertEquals(202, solicitud.estado());
        assertNotNull(capturaEnlaces.ultimo());
        String token = capturaEnlaces.ultimo().token();
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM enlace_cuenta WHERE id_cuenta = ? AND tipo = 'PRIMER_INGRESO'"
                        + " AND usado_en IS NULL", Integer.class, idSocioNuevo));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM enlace_cuenta WHERE token_hash = ?", Integer.class, token),
                "El token no debe almacenarse en claro");

        assertEquals(401, login(ciSocioNuevo, "SOCIO").estado(), "Antes de completar no puede entrar");

        Respuesta completar = post("/api/auth/primer-ingreso/completar", null, """
                {"token":"%s","direccion":"Av. Italia 1234","telefono1":"099123456",
                 "telefono2":null,"password":"%s"}
                """.formatted(token, "Nueva-Clave-9"));
        assertEquals(true, completar.estado() / 100 == 2, "estado " + completar.estado() + completar.cuerpo());

        assertTrue(jdbc.queryForObject(
                "SELECT primer_ingreso_completado FROM cuenta WHERE id_cuenta = ?",
                Boolean.class, idSocioNuevo));
        assertEquals(200, login(ciSocioNuevo, "Nueva-Clave-9", "SOCIO").estado());
    }

    @Test
    void primerIngresoRechazaEnlaceInvalidoReutilizadoYExpirado() {
        Respuesta invalido = post("/api/auth/primer-ingreso/completar", null, """
                {"token":"inventado","direccion":"Calle 1","telefono1":"099123456","password":"Nueva-Clave-9"}
                """);
        assertEquals(400, invalido.estado());
        assertEquals("ENLACE_INVALIDO", invalido.codigo());

        post("/api/auth/primer-ingreso/solicitar", null,
                "{\"ci\":\"%s\",\"acceso\":\"SOCIO\"}".formatted(ciSocioNuevo));
        String token = capturaEnlaces.ultimo().token();
        String cuerpo = """
                {"token":"%s","direccion":"Calle 1","telefono1":"099123456","password":"Nueva-Clave-9"}
                """.formatted(token);
        assertEquals(true, post("/api/auth/primer-ingreso/completar", null, cuerpo).estado() / 100 == 2);

        Respuesta reutilizado = post("/api/auth/primer-ingreso/completar", null, cuerpo);
        assertEquals(400, reutilizado.estado());
        assertEquals("ENLACE_INVALIDO", reutilizado.codigo());

        jdbc.update("UPDATE cuenta SET primer_ingreso_completado = false, contrasena_hash = NULL"
                + " WHERE id_cuenta = ?", idSocioNuevo);
        post("/api/auth/primer-ingreso/solicitar", null,
                "{\"ci\":\"%s\",\"acceso\":\"SOCIO\"}".formatted(ciSocioNuevo));
        String segundo = capturaEnlaces.ultimo().token();
        jdbc.update("UPDATE enlace_cuenta SET creado_en = now() - interval '3 days',"
                + " vence_en = now() - interval '2 days' WHERE usado_en IS NULL");
        Respuesta expirado = post("/api/auth/primer-ingreso/completar", null, """
                {"token":"%s","direccion":"Calle 1","telefono1":"099123456","password":"Nueva-Clave-9"}
                """.formatted(segundo));
        assertEquals(400, expirado.estado());
        assertEquals("ENLACE_INVALIDO", expirado.codigo());
        assertFalse(jdbc.queryForObject(
                "SELECT primer_ingreso_completado FROM cuenta WHERE id_cuenta = ?",
                Boolean.class, idSocioNuevo));
    }

    @Test
    void primerIngresoNoRevelaSiLaCuentaExisteNiEnviaEnlaceAUnaCuentaActiva() {
        Respuesta activa = post("/api/auth/primer-ingreso/solicitar", null,
                "{\"ci\":\"%s\",\"acceso\":\"SOCIO\"}".formatted(ciSocio1));
        Respuesta inexistente = post("/api/auth/primer-ingreso/solicitar", null,
                "{\"ci\":\"%s\",\"acceso\":\"SOCIO\"}".formatted(ci(3999999)));

        assertEquals(inexistente.estado(), activa.estado());
        assertEquals(0, capturaEnlaces.cantidad());
        assertNull(capturaEnlaces.ultimo());
    }
}
