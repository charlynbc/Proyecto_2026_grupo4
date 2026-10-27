package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * RF-02 contra PostgreSQL real: vigencia, enlaces sucesivos, empleados y
 * uniformidad de la respuesta. El correo no se envia: el proveedor es "none"
 * y el enlace se captura con el evento de dominio.
 */
class PrimerIngresoCorreoIT extends BaseIntegracionIT {

    private static final String ACTIVACION = """
            {"token":"%s","direccion":"Calle 1","telefono1":"099123456","password":"Nueva-Clave-9"}
            """;

    private Respuesta solicitar(String ci, String acceso) {
        return post("/api/auth/primer-ingreso/solicitar", null,
                "{\"ci\":\"%s\",\"acceso\":\"%s\"}".formatted(ci, acceso));
    }

    private long cuentaPendiente(String ci, String rol) {
        jdbc.update("INSERT INTO persona VALUES (?, 'Pablo', 'Pendiente', DATE '1990-01-01')", ci);
        return jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1)"
                        + " VALUES (?, ?, ?, '099111222') RETURNING id_cuenta",
                Long.class, ci, rol, "u" + ci + "@ejemplo.invalid");
    }

    @Test
    void solicitudRepetidaInvalidaElEnlaceAnteriorYSoloElNuevoActiva() {
        assertEquals(202, solicitar(ciSocioNuevo, "SOCIO").estado());
        String primero = capturaEnlaces.ultimo().token();
        assertEquals(202, solicitar(ciSocioNuevo, "SOCIO").estado());
        String segundo = capturaEnlaces.ultimo().token();
        assertNotEquals(primero, segundo);

        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM enlace_cuenta WHERE id_cuenta = ? AND usado_en IS NULL",
                Integer.class, idSocioNuevo));

        Respuesta anterior = post("/api/auth/primer-ingreso/completar", null, ACTIVACION.formatted(primero));
        assertEquals(400, anterior.estado());
        assertEquals("ENLACE_INVALIDO", anterior.codigo());

        assertEquals(200, post("/api/auth/primer-ingreso/completar", null,
                ACTIVACION.formatted(segundo)).estado());
        assertEquals(200, login(ciSocioNuevo, "Nueva-Clave-9", "SOCIO").estado());
    }

    @Test
    void elEnlaceVenceA24HorasYSoloSeGuardaSuHash() {
        assertEquals(202, solicitar(ciSocioNuevo, "SOCIO").estado());
        String token = capturaEnlaces.ultimo().token();

        long minutos = jdbc.queryForObject(
                "SELECT round(extract(epoch FROM (vence_en - now())) / 60)::bigint"
                        + " FROM enlace_cuenta WHERE id_cuenta = ?", Long.class, idSocioNuevo);
        assertTrue(minutos >= 24 * 60 - 2 && minutos <= 24 * 60, "minutos hasta el vencimiento: " + minutos);
        assertEquals(64, jdbc.queryForObject(
                "SELECT length(token_hash) FROM enlace_cuenta WHERE id_cuenta = ?",
                Integer.class, idSocioNuevo));
        assertTrue(token.length() >= 43, "token de al menos 256 bits");
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM enlace_cuenta WHERE token_hash = ?", Integer.class, token));
    }

    @Test
    void empleadoPendienteActivaPorSuAccesoYLuegoIngresaComoEmpleado() {
        String ci = ci(3000001);
        cuentaPendiente(ci, "MEDICO");

        assertEquals(202, solicitar(ci, "SOCIO").estado());
        assertNull(capturaEnlaces.ultimo(), "Un empleado no recibe enlace por el acceso SOCIO");

        assertEquals(202, solicitar(ci, "EMPLEADO").estado());
        assertNotNull(capturaEnlaces.ultimo());
        Respuesta completar = post("/api/auth/primer-ingreso/completar", null,
                ACTIVACION.formatted(capturaEnlaces.ultimo().token()));
        assertEquals(200, completar.estado());
        assertTrue(completar.cuerpo().contains("\"rol\":\"MEDICO\""), completar.cuerpo());

        assertEquals(401, login(ci, "Nueva-Clave-9", "SOCIO").estado());
        assertEquals(200, login(ci, "Nueva-Clave-9", "EMPLEADO").estado());
    }

    @Test
    void laRespuestaEsIdenticaParaPendienteActivaInexistenteEInactiva() {
        String inactiva = ci(3000002);
        long idInactiva = cuentaPendiente(inactiva, "SOCIO");
        jdbc.update("UPDATE cuenta SET habilitada = false WHERE id_cuenta = ?", idInactiva);

        Respuesta pendiente = solicitar(ciSocioNuevo, "SOCIO");
        Respuesta activa = solicitar(ciSocio1, "SOCIO");
        Respuesta inexistente = solicitar(ci(3999999), "SOCIO");
        Respuesta inhabilitada = solicitar(inactiva, "SOCIO");

        for (Respuesta r : new Respuesta[] {activa, inexistente, inhabilitada}) {
            assertEquals(pendiente.estado(), r.estado());
            assertEquals(pendiente.cuerpo(), r.cuerpo());
        }
        assertEquals(202, pendiente.estado());
        assertEquals(1, capturaEnlaces.cantidad(), "Solo la cuenta pendiente recibe enlace");
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM enlace_cuenta WHERE id_cuenta = ?", Integer.class, idInactiva));
    }
}
