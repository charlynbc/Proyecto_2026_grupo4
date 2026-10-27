package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

/** RF-08: la disponibilidad solo ofrece turnos activos de medicos habilitados. */
class DisponibilidadIT extends BaseIntegracionIT {

    private int disponibles(String query) {
        Respuesta r = get("/api/disponibilidad?especialidadId=" + idEspecialidad + query,
                tokenSocio(ciSocio1));
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json().path("items").size();
    }

    @Test
    void noOfreceNumerosDeUnMedicoInhabilitado() {
        long turno = sembrarTurno(hoy().plusDays(5), 3);
        assertEquals(3, disponibles(""));
        assertEquals(3, disponibles("&medicoId=" + idMedico));

        jdbc.update("UPDATE cuenta SET habilitada = false WHERE id_cuenta = ?", idMedico);

        assertEquals(0, disponibles(""));
        assertEquals(0, disponibles("&medicoId=" + idMedico));
        Respuesta reserva = post("/api/consultas", tokenSocio(ciSocio1),
                "{\"numeroId\":%d}".formatted(numeroId(turno, 1)));
        assertEquals(409, reserva.estado(), reserva.cuerpo());
        assertEquals(0, contar("consulta"));
    }

    @Test
    void respetaEspecialidadFechasYTurnosActivos() {
        sembrarTurno(hoy().plusDays(3), 2);
        long suspendido = sembrarTurno(hoy().plusDays(10), 2);
        jdbc.update("UPDATE turno SET estado = 'SUSPENDIDO' WHERE id_turno = ?", suspendido);
        sembrarTurno(hoy().plusDays(40), 2);

        assertEquals(2, disponibles(""), "Excluye suspendido y mas de 30 dias");
        assertEquals(2, disponibles("&fechaDesde=" + hoy().plusDays(3) + "&fechaHasta=" + hoy().plusDays(3)));
        assertEquals(0, disponibles("&fechaDesde=" + hoy().plusDays(4)));
        Respuesta otra = get("/api/disponibilidad?especialidadId=" + idEspecialidadConPase,
                tokenSocio(ciSocio1));
        assertEquals(0, otra.json().path("items").size());
        assertEquals(401, get("/api/disponibilidad?especialidadId=" + idEspecialidad, null).estado());
        assertEquals(403, get("/api/disponibilidad?especialidadId=" + idEspecialidad,
                tokenEmpleado(ciFuncionario)).estado());
        assertEquals(400, get("/api/disponibilidad", tokenSocio(ciSocio1)).estado());
    }
}
