package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/**
 * RF-45 y RF-35: cada fila de GET /api/usuarios trae puedeInactivar, que sale
 * de la misma regla que POST /api/usuarios/{id}/inactivar.
 */
class PadronPuedeInactivarIT extends BaseIntegracionIT {

    private String admin() {
        return tokenEmpleado(ciAdmin);
    }

    private boolean puedeInactivar(long idCuenta) {
        Respuesta r = get("/api/usuarios?size=100", admin());
        assertEquals(200, r.estado(), r.cuerpo());
        for (JsonNode fila : r.json().path("items")) {
            if (fila.path("id").asLong() == idCuenta) {
                assertTrue(fila.path("puedeInactivar").isBoolean(),
                        "puedeInactivar es un booleano");
                return fila.path("puedeInactivar").asBoolean();
            }
        }
        throw new AssertionError("La cuenta " + idCuenta + " no esta en el listado");
    }

    /** El listado dice false si y solo si inactivar no responde 200. */
    private void verificarParidad(long idCuenta) {
        boolean enElListado = puedeInactivar(idCuenta);

        Respuesta r = post("/api/usuarios/%d/inactivar".formatted(idCuenta), admin(), null);

        assertEquals(enElListado, r.estado() == 200,
                "listado=" + enElListado + " inactivar=" + r.estado());
        if (!enElListado) {
            assertTrue(r.estado() == 409 || r.estado() == 400, r.cuerpo());
        }
    }

    @Test
    void laFilaPropiaDelAdministradorNoSePuedeInactivar() {
        assertEquals(false, puedeInactivar(idAdmin));
    }

    @Test
    void unEmpleadoSinBloqueosSePuedeInactivar() {
        assertEquals(true, puedeInactivar(idFuncionario));
        assertEquals(true, puedeInactivar(idFuncionario2));
        assertEquals(true, puedeInactivar(idMedico));
    }

    @Test
    void unSocioNoSePuedeInactivar() {
        assertEquals(false, puedeInactivar(idSocio1));
    }

    @Test
    void unaCuentaInactivaNoSePuedeInactivar() {
        jdbc.update("UPDATE cuenta SET habilitada = FALSE WHERE id_cuenta = ?",
                idFuncionario2);

        assertEquals(false, puedeInactivar(idFuncionario2));
    }

    @Test
    void unMedicoConTurnosActivosNoSePuedeInactivar() {
        sembrarTurno(hoy().plusDays(7), 2);

        assertEquals(false, puedeInactivar(idMedico));
    }

    @Test
    void unMedicoConConsultasAgendadasNoSePuedeInactivar() {
        long turno = sembrarTurno(hoy().plusDays(5), 1);
        jdbc.update("UPDATE turno SET estado = 'SUSPENDIDO' WHERE id_turno = ?", turno);
        sembrarConsulta(idSocio1, numeroId(turno, 1));

        assertEquals(false, puedeInactivar(idMedico));
    }

    @Test
    void unMedicoConUnTurnoDeUnDiaTerminadoSePuedeInactivar() {
        sembrarTurno(hoy().minusDays(7), 2);

        assertEquals(true, puedeInactivar(idMedico));
    }

    @Test
    void elListadoCoincideConInactivarEnLaCuentaPropiaYLosEmpleados() {
        assertNotNull(idAdmin);
        verificarParidad(idAdmin);
        verificarParidad(idFuncionario);
        verificarParidad(idMedico);
        verificarParidad(idSocio1);
    }

    @Test
    void elListadoCoincideConInactivarConUnMedicoConTurnos() {
        sembrarTurno(hoy().plusDays(7), 2);

        verificarParidad(idMedico);
    }

    @Test
    void elListadoCoincideConInactivarConUnaCuentaYaInactiva() {
        jdbc.update("UPDATE cuenta SET habilitada = FALSE WHERE id_cuenta = ?",
                idFuncionario2);

        verificarParidad(idFuncionario2);
    }
}
