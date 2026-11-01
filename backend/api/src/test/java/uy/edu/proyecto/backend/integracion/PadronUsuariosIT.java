package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-35: padron de usuarios (GET /api/usuarios) contra PostgreSQL real. */
class PadronUsuariosIT extends BaseIntegracionIT {

    private JsonNode listar(String query) {
        Respuesta r = get("/api/usuarios" + query, tokenEmpleado(ciAdmin));
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    private static List<String> campo(JsonNode pagina, String nombre) {
        List<String> valores = new ArrayList<>();
        pagina.path("items").forEach(i -> valores.add(i.path(nombre).asString()));
        return valores;
    }

    @Test
    void devuelveUnaFilaPorCuentaYUnaPersonaConVariasCuentasApareceVariasVeces() {
        jdbc.update("INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                + " primer_ingreso_completado) VALUES (?, 'FUNCIONARIO', 'doble@ejemplo.invalid',"
                + " '099111222', 'Calle 1', 'x', true)", ciSocio1);

        JsonNode todos = listar("?size=100");
        JsonNode porCi = listar("?q=" + ciSocio1);

        assertEquals(contar("cuenta"), todos.path("total").asInt());
        assertEquals(contar("cuenta"), todos.path("items").size());
        assertEquals(2, porCi.path("total").asInt());
        assertEquals(List.of("FUNCIONARIO", "SOCIO"),
                campo(porCi, "rol").stream().sorted().toList());
    }

    @Test
    void muestraRolEstadoYActivacionSinExponerCredenciales() {
        jdbc.update("UPDATE cuenta SET habilitada = false WHERE id_cuenta = ?", idSocio2);

        JsonNode nueva = listar("?q=" + ciSocioNuevo).path("items").get(0);
        JsonNode inactiva = listar("?q=" + ciSocio2).path("items").get(0);

        assertEquals("SOCIO", nueva.path("rol").asString());
        assertFalse(nueva.path("activada").asBoolean());
        assertEquals("INACTIVA", inactiva.path("estado").asString());
        assertTrue(inactiva.path("activada").asBoolean());
        String cuerpo = get("/api/usuarios?size=100", tokenEmpleado(ciAdmin)).cuerpo();
        assertFalse(cuerpo.contains("contrasena"), "No debe exponer hashes");
        assertFalse(cuerpo.contains("token"), "No debe exponer tokens");
    }

    @Test
    void filtrosCombinablesPorRolEstadoYTexto() {
        jdbc.update("UPDATE cuenta SET habilitada = false WHERE id_cuenta = ?", idSocio3);

        assertEquals(5, listar("?rol=SOCIO").path("total").asInt());
        assertEquals(1, listar("?rol=SOCIO&estado=INACTIVA").path("total").asInt());
        assertEquals(4, listar("?rol=SOCIO&estado=ACTIVA").path("total").asInt());
        assertEquals(1, listar("?rol=SOCIO&estado=ACTIVA&q=Soca").path("total").asInt());
        assertEquals(0, listar("?rol=MEDICO&q=Soca").path("total").asInt());
        assertEquals(1, listar("?rol=medico").path("total").asInt(), "El rol no distingue mayusculas");
    }

    @Test
    void qYTextoSonEquivalentesYUnaContradiccionSeRechaza() {
        assertEquals(listar("?q=Soca").path("items"), listar("?texto=Soca").path("items"));
        assertEquals(listar("?q=Soca").path("items"), listar("?q=Soca&texto=Soca").path("items"));
        assertEquals(400, get("/api/usuarios?q=Soca&texto=Sosa", tokenEmpleado(ciAdmin)).estado());
    }

    @Test
    void laBusquedaTrataPorcentajeYGuionBajoComoLiterales() {
        jdbc.update("UPDATE persona SET apellido = 'Per_z' WHERE ci = ?", ciSocio1);
        jdbc.update("UPDATE persona SET apellido = 'Perez' WHERE ci = ?", ciSocio2);

        assertEquals(1, listar("?q=Per_z").path("total").asInt());
        assertEquals(0, listar("?q=%25").path("total").asInt());
        assertEquals(1, listar("?q=_").path("total").asInt());
    }

    @Test
    void ordenaPorApellidoOFechaAltaEnAmbosSentidos() {
        jdbc.update("UPDATE cuenta SET fecha_alta = TIMESTAMPTZ '2026-01-01 10:00:00-03'"
                + " WHERE id_cuenta = ?", idSocio1);
        jdbc.update("UPDATE cuenta SET fecha_alta = TIMESTAMPTZ '2026-06-01 10:00:00-03'"
                + " WHERE id_cuenta = ?", idSocio2);

        List<String> asc = campo(listar("?rol=SOCIO&orden=apellido&sentido=asc&size=100"), "apellido");
        List<String> desc = campo(listar("?rol=SOCIO&orden=apellido&sentido=desc&size=100"), "apellido");
        assertEquals(asc.stream().sorted().toList(), asc);
        assertEquals(asc.reversed(), desc);

        List<String> recientes = campo(
                listar("?rol=SOCIO&orden=fechaAlta&sentido=desc&size=100"), "ci");
        List<String> antiguas = campo(
                listar("?rol=SOCIO&orden=fechaAlta&sentido=asc&size=100"), "ci");
        assertTrue(antiguas.indexOf(ciSocio1) < antiguas.indexOf(ciSocio2));
        assertTrue(recientes.indexOf(ciSocio2) < recientes.indexOf(ciSocio1));
    }

    @Test
    void ordenYSentidoInvalidosDan400() {
        String admin = tokenEmpleado(ciAdmin);
        assertEquals(400, get("/api/usuarios?orden=contrasena_hash", admin).estado());
        assertEquals(400, get("/api/usuarios?orden=apellido;DROP", admin).estado());
        assertEquals(400, get("/api/usuarios?sentido=arriba", admin).estado());
        assertEquals(400, get("/api/usuarios?rol=ROOT", admin).estado());
        assertEquals(400, get("/api/usuarios?estado=BORRADA", admin).estado());
    }

    @Test
    void paginacionEstableSinRepetirNiOmitirCuentas() {
        // Mismo apellido y misma fecha de alta: el desempate por id mantiene el orden.
        jdbc.update("UPDATE persona SET apellido = 'Igual'");
        jdbc.update("UPDATE cuenta SET fecha_alta = TIMESTAMPTZ '2026-03-03 10:00:00-03'");

        List<String> vistos = new ArrayList<>();
        for (int pagina = 0; pagina < 4; pagina++) {
            JsonNode p = listar("?size=3&page=" + pagina);
            assertEquals(contar("cuenta"), p.path("total").asInt());
            assertEquals(pagina, p.path("page").asInt());
            vistos.addAll(campo(p, "id"));
        }
        assertEquals(contar("cuenta"), vistos.size());
        assertEquals(vistos.size(), vistos.stream().distinct().count());
        assertEquals(0, listar("?size=3&page=50").path("items").size());
        assertEquals(400, get("/api/usuarios?page=-1", tokenEmpleado(ciAdmin)).estado());
        assertEquals(400, get("/api/usuarios?size=0", tokenEmpleado(ciAdmin)).estado());
        assertEquals(400, get("/api/usuarios?size=101", tokenEmpleado(ciAdmin)).estado());
    }

    @Test
    void soloElAdministradorPuedeConsultarElPadron() {
        assertEquals(401, get("/api/usuarios?q=Soca", null).estado());
        assertEquals(403, get("/api/usuarios?q=Soca", tokenSocio(ciSocio1)).estado());
        assertEquals(403, get("/api/usuarios?q=Soca", tokenEmpleado(ciFuncionario)).estado());
        assertEquals(403, get("/api/usuarios?q=Soca", tokenEmpleado(ciMedico)).estado());
        assertEquals(200, get("/api/usuarios?q=Soca", tokenEmpleado(ciAdmin)).estado());
    }
}
