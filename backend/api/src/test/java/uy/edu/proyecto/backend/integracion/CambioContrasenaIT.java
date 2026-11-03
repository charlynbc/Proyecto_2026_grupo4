package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;

/** RF-04 contra PostgreSQL real: cambio de contrasena del usuario autenticado. */
class CambioContrasenaIT extends BaseIntegracionIT {

    private int sesionesActivas(long cuenta) {
        return jdbc.queryForObject(
                "SELECT count(*) FROM sesion WHERE id_cuenta = ? AND revocada_en IS NULL",
                Integer.class, cuenta);
    }

    @Test
    void cambioCorrectoPermiteEntrarConLaNuevaYNoConLaVieja() {
        String token = tokenSocio(ciSocio1);

        Respuesta cambio = post("/api/auth/cambiar-contrasena", token, """
                {"passwordActual":"%s","passwordNueva":"Clave-Nueva-9"}
                """.formatted(CLAVE));
        assertEquals(204, cambio.estado(), cambio.cuerpo());

        assertEquals(401, login(ciSocio1, CLAVE, "SOCIO").estado());
        assertEquals(200, login(ciSocio1, "Clave-Nueva-9", "SOCIO").estado());
    }

    @Test
    void contrasenaActualIncorrectaDevuelve400SinCambiarNada() {
        String token = tokenSocio(ciSocio1);

        Respuesta r = post("/api/auth/cambiar-contrasena", token, """
                {"passwordActual":"no-es-esta","passwordNueva":"Clave-Nueva-9"}
                """);
        assertEquals(400, r.estado());
        assertEquals("CONTRASENA_ACTUAL_INCORRECTA", r.codigo());

        assertEquals(200, login(ciSocio1, CLAVE, "SOCIO").estado());
    }

    @Test
    void contrasenaNuevaInvalidaDevuelve400() {
        String token = tokenSocio(ciSocio1);

        Respuesta corta = post("/api/auth/cambiar-contrasena", token, """
                {"passwordActual":"%s","passwordNueva":"corta"}
                """.formatted(CLAVE));
        assertEquals(400, corta.estado());
        assertEquals("VALIDACION", corta.codigo());

        Respuesta sinCampos = post("/api/auth/cambiar-contrasena", token, "{}");
        assertEquals(400, sinCampos.estado());
        assertEquals("VALIDACION", sinCampos.codigo());

        assertEquals(200, login(ciSocio1, CLAVE, "SOCIO").estado());
    }

    @Test
    void sinAutenticacionDevuelve401() {
        Respuesta r = post("/api/auth/cambiar-contrasena", null, """
                {"passwordActual":"%s","passwordNueva":"Clave-Nueva-9"}
                """.formatted(CLAVE));
        assertEquals(401, r.estado());
    }

    @Test
    void cuentaInactivaNoPuedeCambiarLaContrasena() {
        String token = tokenSocio(ciSocio1);
        jdbc.update("UPDATE cuenta SET habilitada = FALSE,"
                + " ultimo_inactivador = ?, ultima_inactivacion_en = CURRENT_TIMESTAMP"
                + " WHERE id_cuenta = ?", idAdmin, idSocio1);

        Respuesta r = post("/api/auth/cambiar-contrasena", token, """
                {"passwordActual":"%s","passwordNueva":"Clave-Nueva-9"}
                """.formatted(CLAVE));
        assertEquals(401, r.estado(), "El validador de cuenta vigente rechaza el token");
    }

    @Test
    void elCambioRevocaLasDemasSesionesYConservaLaActual() {
        Respuesta sesionA = login(ciSocio1, "SOCIO");
        Respuesta sesionB = login(ciSocio1, "SOCIO");
        assertEquals(2, sesionesActivas(idSocio1));

        Respuesta cambio = enviar("POST", "/api/auth/cambiar-contrasena",
                sesionA.json().path("token").asString(),
                sesionA.refreshToken(), """
                {"passwordActual":"%s","passwordNueva":"Clave-Nueva-9"}
                """.formatted(CLAVE));
        assertEquals(204, cambio.estado(), cambio.cuerpo());
        assertEquals(1, sesionesActivas(idSocio1));

        // La sesion B quedo revocada: su refresh ya no sirve.
        Respuesta refreshB = enviar("POST", "/api/auth/refresh", null,
                sesionB.refreshToken(), null);
        assertEquals(401, refreshB.estado());

        // La sesion A sigue vigente.
        Respuesta refreshA = enviar("POST", "/api/auth/refresh", null,
                sesionA.refreshToken(), null);
        assertEquals(200, refreshA.estado());
    }

    @Test
    void dosCambiosConcurrentesSeSerializanYElSegundoUsaLaClaveVigente()
            throws Exception {
        String token = tokenSocio(ciSocio1);
        CyclicBarrier barrera = new CyclicBarrier(2);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            // Ambos conocen la clave actual: los dos cambios son validos y se
            // serializan por el bloqueo de la fila; gana el ultimo commit.
            Future<Respuesta> primero = pool.submit(() -> {
                barrera.await(10, TimeUnit.SECONDS);
                return post("/api/auth/cambiar-contrasena", token, """
                        {"passwordActual":"%s","passwordNueva":"Clave-Uno-123"}
                        """.formatted(CLAVE));
            });
            Future<Respuesta> segundo = pool.submit(() -> {
                barrera.await(10, TimeUnit.SECONDS);
                return post("/api/auth/cambiar-contrasena", token, """
                        {"passwordActual":"%s","passwordNueva":"Clave-Dos-123"}
                        """.formatted(CLAVE));
            });

            List<Respuesta> respuestas = List.of(primero.get(), segundo.get());
            for (Respuesta r : respuestas) {
                assertTrue(r.estado() == 204 || r.estado() == 400,
                        "estado inesperado: " + r.estado());
            }
            assertTrue(respuestas.stream().anyMatch(r -> r.estado() == 204),
                    "al menos un cambio debe aplicarse");

            boolean entraConUno =
                    login(ciSocio1, "Clave-Uno-123", "SOCIO").estado() == 200;
            boolean entraConDos =
                    login(ciSocio1, "Clave-Dos-123", "SOCIO").estado() == 200;
            assertTrue(entraConUno ^ entraConDos,
                    "exactamente una contrasena final debe quedar vigente");
            assertEquals(401, login(ciSocio1, CLAVE, "SOCIO").estado());
        } finally {
            pool.shutdownNow();
        }
    }
}
