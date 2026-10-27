package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** Selector de médicos del alta de turno (GET /api/medicos) con PostgreSQL real. */
class MedicoIT extends BaseIntegracionIT {

    private long medicoCardiologo() {
        jdbc.update("INSERT INTO persona VALUES (?, 'Carla', 'Corazon', DATE '1980-01-01')", ci(1000010));
        long id = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'MEDICO', 'carla@ejemplo.invalid',"
                        + " '099111222', 'Calle 1', ?, true) RETURNING id_cuenta",
                Long.class, ci(1000010), passwordEncoder.encode(CLAVE));
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", id, idEspecialidadConPase);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", id, idEspecialidad);
        return id;
    }

    private void medicoInhabilitado() {
        jdbc.update("INSERT INTO persona VALUES (?, 'Ines', 'Inactiva', DATE '1979-01-01')", ci(1000011));
        long id = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'MEDICO', 'ines@ejemplo.invalid',"
                        + " '099111222', 'Calle 2', ?, true) RETURNING id_cuenta",
                Long.class, ci(1000011), passwordEncoder.encode(CLAVE));
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", id, idEspecialidad);
        jdbc.update("UPDATE cuenta SET habilitada = FALSE WHERE id_cuenta = ?", id);
    }

    private List<Long> ids(JsonNode lista) {
        List<Long> ids = new ArrayList<>();
        lista.forEach(m -> ids.add(m.path("id").asLong()));
        return ids;
    }

    @Test
    void listaJsonSoloConMedicosHabilitadosYSusEspecialidades() {
        long cardiologa = medicoCardiologo();
        medicoInhabilitado();

        Respuesta r = get("/api/medicos", tokenEmpleado(ciFuncionario));

        assertEquals(200, r.estado());
        assertTrue(r.json().isArray(), "El backend devuelve una lista JSON, no un objeto");
        assertEquals(List.of(cardiologa, idMedico), ids(r.json()), "Orden por apellido: Corazon, Medina");
        JsonNode primera = r.json().get(0);
        assertEquals(2, primera.path("especialidades").size());
        assertTrue(primera.path("especialidades").get(0).has("requierePase"));
        assertTrue(!primera.has("correo") && !primera.has("ci"));
    }

    @Test
    void filtraPorEspecialidadYSinResultadosDevuelveListaVacia() {
        long cardiologa = medicoCardiologo();
        String token = tokenEmpleado(ciFuncionario);

        assertEquals(List.of(cardiologa),
                ids(get("/api/medicos?especialidadId=" + idEspecialidadConPase, token).json()));
        assertEquals(List.of(cardiologa, idMedico),
                ids(get("/api/medicos?especialidadId=" + idEspecialidad, token).json()));

        Respuesta vacia = get("/api/medicos?especialidadId=999999", token);
        assertEquals(200, vacia.estado());
        assertEquals("[]", vacia.cuerpo().strip());
    }

    @Test
    void elMedicoElegidoEnElSelectorPermiteGuardarElTurnoSemanal() {
        String token = tokenEmpleado(ciFuncionario);
        long elegido = ids(get("/api/medicos?especialidadId=" + idEspecialidad, token).json()).get(0);
        LocalDate fecha = hoy().plusDays(10);

        Respuesta r = post("/api/turnos-semanales", token, """
                {"medicoId":%d,"especialidadId":%d,"consultorioId":%d,"diaSemana":%d,
                 "fechaInicio":"%s","fechaFin":"%s",
                 "numeros":[{"numero":1,"horaInicio":"09:00","horaFin":"09:20"}]}
                """.formatted(elegido, idEspecialidad, idConsultorio, diaSemana(fecha), fecha, fecha));

        assertEquals(201, r.estado(), r.cuerpo());
    }

    @Test
    void sinSesionOConRolSocioNoSeListan() {
        assertEquals(401, get("/api/medicos", null).estado());
        assertEquals(403, get("/api/medicos", tokenSocio(ciSocio1)).estado());
    }
}
