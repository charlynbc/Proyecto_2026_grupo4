package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

/** Permisos reales de los cuatro roles: permitidos, prohibidos y base de datos intacta. */
class RolesIT extends BaseIntegracionIT {

    private record Endpoint(String metodo, String ruta, String rolPermitido) {
    }

    private static final List<Endpoint> ENDPOINTS = List.of(
            new Endpoint("POST", "/api/especialidades", "ADMINISTRADOR"),
            new Endpoint("POST", "/api/consultorios", "ADMINISTRADOR"),
            new Endpoint("POST", "/api/usuarios", "ADMINISTRADOR"),
            new Endpoint("POST", "/api/turnos-semanales", "FUNCIONARIO"),
            new Endpoint("POST", "/api/turnos/suspensiones/previsualizar", "FUNCIONARIO"),
            new Endpoint("POST", "/api/turnos/suspensiones", "FUNCIONARIO"),
            new Endpoint("POST", "/api/turnos/rehabilitaciones", "FUNCIONARIO"),
            new Endpoint("GET", "/api/turnos", "FUNCIONARIO"),
            new Endpoint("GET", "/api/agendas", "FUNCIONARIO"),
            new Endpoint("GET", "/api/avisos-llegada/consultas-hoy?ci=12345678", "FUNCIONARIO"),
            new Endpoint("POST", "/api/avisos-llegada", "FUNCIONARIO"),
            new Endpoint("GET", "/api/disponibilidad?especialidadId=1", "SOCIO"),
            new Endpoint("POST", "/api/consultas", "SOCIO"),
            new Endpoint("GET", "/api/consultas", "SOCIO"),
            new Endpoint("GET", "/api/medico/turnos", "MEDICO"),
            new Endpoint("POST", "/api/medico/consultas/1/resultado", "MEDICO")
    );

    private static final List<String> ROLES = List.of("SOCIO", "FUNCIONARIO", "MEDICO", "ADMINISTRADOR");

    private Map<String, String> tokens() {
        return Map.of(
                "SOCIO", tokenSocio(ciSocio1),
                "FUNCIONARIO", tokenEmpleado(ciFuncionario),
                "MEDICO", tokenEmpleado(ciMedico),
                "ADMINISTRADOR", tokenEmpleado(ciAdmin));
    }

    private int[] huella() {
        return new int[] {
                contar("especialidad"), contar("consultorio"), contar("cuenta"),
                contar("turno_semanal"), contar("turno"), contar("consulta"),
                contar("aviso_llegada"), contar("turno_evento"), contar("atencion")
        };
    }

    @Test
    void cadaEndpointExigeSuRolYLosOtrosRecibenUn403SinTocarLaBase() {
        Map<String, String> tokens = tokens();
        int[] antes = huella();

        for (Endpoint e : ENDPOINTS) {
            String cuerpo = e.metodo().equals("POST") ? "{}" : null;
            Respuesta anonimo = enviar(e.metodo(), e.ruta(), null, null, cuerpo);
            assertEquals(401, anonimo.estado(), "Sin sesion: " + e);

            for (String rol : ROLES) {
                Respuesta r = enviar(e.metodo(), e.ruta(), tokens.get(rol), null, cuerpo);
                if (rol.equals(e.rolPermitido())) {
                    assertTrue(r.estado() != 401 && r.estado() != 403,
                            "Rol permitido bloqueado: " + rol + " " + e + " -> " + r.estado());
                } else {
                    assertEquals(403, r.estado(), "Rol prohibido " + rol + " en " + e);
                }
            }
        }
        // Los cuerpos vacios de los roles permitidos fallan validacion: nada se persiste.
        org.junit.jupiter.api.Assertions.assertArrayEquals(antes, huella());
    }

    @Test
    void rutasDesconocidasYErrorNoSonPublicas() {
        assertEquals(401, get("/api/ruta-inexistente", null).estado());
        assertEquals(401, get("/api", null).estado());
        assertEquals(401, get("/error", null).estado());
        assertFalse(get("/api/ruta-inexistente", tokenSocio(ciSocio1)).estado() == 200);
        assertEquals(401, get("/api/consultas", null).estado());
    }

    @Test
    void recursosPublicosDeFlutterNoExigenSesionPeroLaApiSi() {
        for (String ruta : List.of("/", "/index.html", "/canvaskit/test.js", "/assets/test.txt")) {
            assertEquals(200, get(ruta, null).estado(), ruta);
        }
        assertEquals(401, get("/api/disponibilidad?especialidadId=1", null).estado());
    }

    @Test
    void elRegistroPublicoAntiguoYElLoginAntiguoNoEstanDisponibles() {
        assertEquals(401, post("/api/usuarios", null, "{}").estado());
        assertEquals(401, post("/api/usuarios/registro", null, "{}").estado());
        Respuesta viejo = post("/api/auth/login", null, "{\"cedula\":\"1\",\"clave\":\"x\"}");
        assertTrue(viejo.estado() == 400 || viejo.estado() == 401);
    }

    @Test
    void unTokenDeUnRolNoSirveParaOtroAunqueLaCuentaExista() {
        String socio = tokenSocio(ciSocio1);
        int[] antes = huella();
        assertEquals(403, post("/api/turnos/suspensiones", socio, "{\"ids\":[1],\"cantidadConfirmada\":0}").estado());
        assertEquals(403, post("/api/usuarios", socio, "{}").estado());
        org.junit.jupiter.api.Assertions.assertArrayEquals(antes, huella());
    }
}
