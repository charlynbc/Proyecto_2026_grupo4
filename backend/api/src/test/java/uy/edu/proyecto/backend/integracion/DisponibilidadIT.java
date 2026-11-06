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
    void socioBuscaPorMedicoSinEspecialidadYEncuentraDistintasEspecialidades() {
        sembrarTurno(hoy().plusDays(4), 1);
        long segundo = sembrarTurno(hoy().plusDays(6), 1);
        jdbc.update("INSERT INTO medico_especialidad (id_medico, id_especialidad)"
                + " VALUES (?, ?) ON CONFLICT DO NOTHING", idMedico, idEspecialidadConPase);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ?"
                + " WHERE id_turno_semanal = (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)",
                idEspecialidadConPase, segundo);

        String token = tokenSocio(ciSocio1);
        Respuesta soloMedico = get("/api/disponibilidad?medicoId=" + idMedico, token);
        assertEquals(200, soloMedico.estado(), soloMedico.cuerpo());
        assertEquals(2, soloMedico.json().path("items").size());
        assertEquals(idEspecialidad, soloMedico.json().path("items").get(0)
                .path("especialidad").path("id").asLong());
        assertEquals(idEspecialidadConPase, soloMedico.json().path("items").get(1)
                .path("especialidad").path("id").asLong());

        Respuesta ambas = get("/api/disponibilidad?medicoId=" + idMedico
                + "&especialidadId=" + idEspecialidadConPase, token);
        assertEquals(200, ambas.estado(), ambas.cuerpo());
        assertEquals(1, ambas.json().path("items").size());
        Respuesta otra = get("/api/disponibilidad?medicoId=" + idMedico
                + "&especialidadId=999999", token);
        assertEquals(404, otra.estado(), otra.cuerpo());
        Respuesta medicoInexistente = get("/api/disponibilidad?medicoId=999999", token);
        assertEquals(404, medicoInexistente.estado(), medicoInexistente.cuerpo());
        assertEquals(400, get("/api/disponibilidad", token).estado());
    }

    @Test
    void ambosFiltrosValidosSinRelacionDevuelvenListaVacia() {
        sembrarTurno(hoy().plusDays(4), 1);
        Respuesta r = get("/api/disponibilidad?medicoId=" + idMedico
                + "&especialidadId=" + idEspecialidadConPase, tokenSocio(ciSocio1));
        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("items").size());
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
