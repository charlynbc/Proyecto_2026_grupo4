package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.crypto.spec.SecretKeySpec;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

/**
 * Verifica contra PostgreSQL real que un JWT valido criptograficamente deja de autorizar cuando
 * la cuenta se inactiva, no existe o fue reactivada despues de su emision.
 */
class CuentasInactivasIT extends BaseIntegracionIT {

    private static final String RUTA = "/api/especialidades";

    @Autowired
    JwtEncoder jwtEncoder;

    private void inactivar(long idCuenta) {
        jdbc.update("""
                UPDATE cuenta SET habilitada = FALSE, ultimo_inactivador = ?,
                       ultima_inactivacion_en = CURRENT_TIMESTAMP WHERE id_cuenta = ?
                """, idAdmin, idCuenta);
    }

    private void reactivar(long idCuenta) {
        jdbc.update("""
                UPDATE cuenta SET habilitada = TRUE, ultimo_reactivador = ?,
                       ultima_reactivacion_en = CURRENT_TIMESTAMP WHERE id_cuenta = ?
                """, idAdmin, idCuenta);
    }

    private static void esperarSegundo() {
        try {
            Thread.sleep(1200);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private String firmar(JwtEncoder encoder, String sub, String rol, Instant emision, Instant vence) {
        JwtClaimsSet claims = JwtClaimsSet.builder().issuer("grupo4-api").subject(sub)
                .claim("role", rol).issuedAt(emision).expiresAt(vence).build();
        return encoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    @Test
    void cuentaActivaConJwtValidoAccede() {
        assertEquals(200, get(RUTA, tokenSocio(ciSocio1)).estado());
        assertEquals(200, get(RUTA, tokenEmpleado(ciAdmin)).estado());
    }

    @Test
    void socioInactivadoDespuesDelLoginPierdeAccesoEnLaSiguienteSolicitud() {
        String token = tokenSocio(ciSocio1);
        assertEquals(200, get(RUTA, token).estado());
        inactivar(idSocio1);
        assertEquals(401, get(RUTA, token).estado());
    }

    @Test
    void funcionarioMedicoYAdministradorInactivadosPierdenAcceso() {
        String funcionario = tokenEmpleado(ciFuncionario);
        String medico = tokenEmpleado(ciMedico);
        String admin = tokenEmpleado(ciAdmin);
        assertEquals(200, get(RUTA, funcionario).estado());
        assertEquals(200, get(RUTA, medico).estado());
        assertEquals(200, get("/api/usuarios", admin).estado());

        inactivar(idFuncionario);
        inactivar(idMedico);
        inactivar(idAdmin);

        assertEquals(401, get(RUTA, funcionario).estado());
        assertEquals(401, get(RUTA, medico).estado());
        assertEquals(401, get("/api/usuarios", admin).estado());
    }

    @Test
    void inactivarUnaCuentaNoAfectaALasDemas() {
        String socio1 = tokenSocio(ciSocio1);
        String socio2 = tokenSocio(ciSocio2);
        inactivar(idSocio1);
        assertEquals(401, get(RUTA, socio1).estado());
        assertEquals(200, get(RUTA, socio2).estado());
    }

    @Test
    void cuentaInexistenteConJwtFirmadoSeRechaza() {
        Instant ahora = Instant.now();
        String token = firmar(jwtEncoder, "9999999", "SOCIO", ahora, ahora.plusSeconds(600));
        assertEquals(401, get(RUTA, token).estado());
    }

    @Test
    void tokenExpiradoSeRechaza() {
        Instant ahora = Instant.now();
        String token = firmar(jwtEncoder, String.valueOf(idSocio1), "SOCIO",
                ahora.minusSeconds(3600), ahora.minusSeconds(1800));
        assertEquals(401, get(RUTA, token).estado());
    }

    @Test
    void tokenConFirmaInvalidaSeRechaza() {
        byte[] otraClave = new byte[32];
        java.util.Arrays.fill(otraClave, (byte) 7);
        JwtEncoder ajeno = NimbusJwtEncoder
                .withSecretKey(new SecretKeySpec(otraClave, "HmacSHA256"))
                .algorithm(MacAlgorithm.HS256).build();
        Instant ahora = Instant.now();
        String token = firmar(ajeno, String.valueOf(idSocio1), "SOCIO", ahora, ahora.plusSeconds(600));
        assertEquals(401, get(RUTA, token).estado());

        String valido = tokenSocio(ciSocio1);
        String alterado = valido.substring(0, valido.length() - 2)
                + (valido.endsWith("AA") ? "BB" : "AA");
        assertEquals(401, get(RUTA, alterado).estado());
    }

    @Test
    void rolAdulteradoEnElTokenNoOtorgaPrivilegios() {
        Instant ahora = Instant.now();
        String token = firmar(jwtEncoder, String.valueOf(idSocio1), "ADMINISTRADOR",
                ahora, ahora.plusSeconds(600));
        assertEquals(401, get("/api/usuarios", token).estado());
    }

    @Test
    void rolNoAutorizadoSigueDandoProhibido() {
        assertEquals(403, get("/api/usuarios", tokenSocio(ciSocio1)).estado());
    }

    @Test
    void sinTokenSeRechazaYLasRutasPublicasSiguenFuncionando() {
        assertEquals(401, get(RUTA, null).estado());
        assertEquals(200, login(ciSocio1, "SOCIO").estado());
        assertEquals("REFRESH_FALTANTE",
                enviar("POST", "/api/auth/refresh", null, null, null).codigo());
    }

    @Test
    void loginDeCuentaInactivaSigueRechazado() {
        inactivar(idSocio1);
        assertEquals(401, login(ciSocio1, "SOCIO").estado());
    }

    @Test
    void reactivacionNoReviveTokensEmitidosAntesPeroPermiteUnLoginNuevo() {
        String anterior = tokenSocio(ciSocio1);
        inactivar(idSocio1);
        assertEquals(401, get(RUTA, anterior).estado());

        reactivar(idSocio1);
        assertEquals(401, get(RUTA, anterior).estado(),
                "El token previo a la inactivacion no debe revivir al reactivar la cuenta");

        esperarSegundo();
        assertEquals(200, get(RUTA, tokenSocio(ciSocio1)).estado());
        assertEquals(401, get(RUTA, anterior).estado());
    }

    @Test
    void refreshTokenDeCuentaInactivaSeRechazaYNoSeReviveAlReactivar() {
        Respuesta sesion = login(ciSocio1, "SOCIO");
        String refresh = sesion.refreshToken();
        assertNotNull(refresh);

        inactivar(idSocio1);
        assertEquals(401,
                enviar("POST", "/api/auth/refresh", null, refresh, null).estado());

        reactivar(idSocio1);
        assertEquals(401,
                enviar("POST", "/api/auth/refresh", null, refresh, null).estado(),
                "La sesion previa a la reactivacion no debe poder renovarse");

        esperarSegundo();
        Respuesta nueva = login(ciSocio1, "SOCIO");
        Respuesta renovada = enviar("POST", "/api/auth/refresh", null, nueva.refreshToken(), null);
        assertEquals(200, renovada.estado());
        assertEquals(200, get(RUTA, renovada.json().path("token").asString()).estado());
    }

    @Test
    void refreshTokenDeCuentaActivaSigueRenovandose() {
        Respuesta sesion = login(ciSocio1, "SOCIO");
        Respuesta renovada = enviar("POST", "/api/auth/refresh", null, sesion.refreshToken(), null);
        assertEquals(200, renovada.estado());
    }

    @Test
    void solicitudesConcurrentesDuranteLaInactivacionNuncaAccedenTrasConfirmarse() throws Exception {
        String token = tokenSocio(ciSocio1);
        AtomicBoolean confirmada = new AtomicBoolean(false);
        AtomicBoolean detener = new AtomicBoolean(false);
        ExecutorService pool = Executors.newFixedThreadPool(6);
        try {
            List<Future<List<int[]>>> trabajos = new ArrayList<>();
            for (int i = 0; i < 6; i++) {
                Callable<List<int[]>> tarea = () -> {
                    List<int[]> resultados = new ArrayList<>();
                    while (!detener.get()) {
                        boolean despues = confirmada.get();
                        int estado = get(RUTA, token).estado();
                        resultados.add(new int[] {despues ? 1 : 0, estado});
                    }
                    return resultados;
                };
                trabajos.add(pool.submit(tarea));
            }
            Thread.sleep(500);
            inactivar(idSocio1);
            confirmada.set(true);
            Thread.sleep(800);
            detener.set(true);

            int accesosPrevios = 0;
            int rechazosPosteriores = 0;
            for (Future<List<int[]>> trabajo : trabajos) {
                for (int[] r : trabajo.get(30, TimeUnit.SECONDS)) {
                    if (r[0] == 1) {
                        assertEquals(401, r[1],
                                "Una solicitud iniciada tras confirmar la inactivacion no debe acceder");
                        rechazosPosteriores++;
                    } else if (r[1] == 200) {
                        accesosPrevios++;
                    } else {
                        assertEquals(401, r[1]);
                    }
                }
            }
            assertTrue(accesosPrevios > 0, "Debio haber accesos antes de inactivar");
            assertTrue(rechazosPosteriores > 0, "Debio haber rechazos despues de inactivar");
        } finally {
            detener.set(true);
            pool.shutdownNow();
        }
    }
}
