package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

/** RF-25: consultas atendidas por el médico contra PostgreSQL real. */
class AtencionesMedicoIT extends BaseIntegracionIT {

    private long idOtroMedico;

    private String tokenMedico() {
        return tokenEmpleado(ciMedico);
    }

    private long otroMedico() {
        if (idOtroMedico == 0) {
            String ci = ci(1000099);
            jdbc.update("INSERT INTO persona VALUES (?, 'Otto', 'Medico', DATE '1980-01-01')",
                    ci);
            idOtroMedico = jdbc.queryForObject(
                    "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion,"
                            + " contrasena_hash, primer_ingreso_completado)"
                            + " VALUES (?, 'MEDICO', ?, '099111222', 'Calle Falsa 123', 'x',"
                            + " TRUE) RETURNING id_cuenta",
                    Long.class, ci, "otto@ejemplo.invalid");
        }
        return idOtroMedico;
    }

    private long sembrarTurnoDe(long medico, long especialidad, LocalDate fecha) {
        long semanal = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, medico, especialidad, idConsultorio, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha) VALUES (?, ?, ?)"
                        + " RETURNING id_turno", Long.class, semanal, idConsultorio, fecha);
        long patron = jdbc.queryForObject(
                "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                        + " VALUES (?, 1, '10:00', '10:20') RETURNING id_numero_semanal",
                Long.class, semanal);
        jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio,"
                + " hora_fin) VALUES (?, ?, 1, '10:00', '10:20')", turno, patron);
        return turno;
    }

    /** Atención registrada por el médico indicado sobre el socio en la fecha dada. */
    private long sembrarAtencion(long medico, long socio, long especialidad,
            LocalDate fecha, String afeccion) {
        long turno = sembrarTurnoDe(medico, especialidad, fecha);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, estado, agendada_en,"
                        + " resultado_registrado_por, fecha_resultado)"
                        + " VALUES (?, ?, 'ATENDIDA', ?::timestamptz, ?, ?::timestamptz)"
                        + " RETURNING id_consulta",
                Long.class, socio, numeroId(turno, 1),
                fecha.minusDays(1) + "T12:00:00-03:00", medico, fecha + "T12:00:00-03:00");
        return jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion, registrada_en)"
                        + " VALUES (?, ?, ?, ?::timestamptz) RETURNING id_atencion",
                Long.class, consulta, medico, afeccion, fecha + "T12:00:00-03:00");
    }

    private void sembrarAtenciones() {
        // Propias: socio1 en Medicina General el 20/10, socio2 en Cardiologia el 25/10.
        sembrarAtencion(idMedico, idSocio1, idEspecialidad,
                LocalDate.of(2026, 10, 20), "Afeccion uno");
        long atencion2 = sembrarAtencion(idMedico, idSocio2, idEspecialidadConPase,
                LocalDate.of(2026, 10, 25), "Afeccion dos");
        jdbc.update("INSERT INTO pase (id_atencion, id_especialidad_destino, vence_el)"
                + " VALUES (?, ?, ?)", atencion2, idEspecialidadConPase, hoy().plusDays(90));
        // Ajena: otro médico atiende a socio1 el 22/10.
        sembrarAtencion(otroMedico(), idSocio1, idEspecialidad,
                LocalDate.of(2026, 10, 22), "Afeccion ajena");
    }

    @Test
    void listaSoloLasAtencionesPropiasOrdenadasPorFechaDescendente() {
        sembrarAtenciones();

        Respuesta r = get("/api/medico/atenciones?fechaDesde=2026-10-01&fechaHasta=2026-10-31",
                tokenMedico());

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(2, r.json().size());
        assertEquals("2026-10-25", r.json().get(0).path("fechaAtencion").asString());
        assertEquals("2026-10-20", r.json().get(1).path("fechaAtencion").asString());
        assertEquals("Afeccion dos", r.json().get(0).path("afeccion").asString());
        assertEquals(ciSocio2, r.json().get(0).path("paciente").path("ci").asString());
        assertEquals("Soca", r.json().get(0).path("paciente").path("apellido").asString());
        assertEquals("Cardiologia",
                r.json().get(0).path("especialidad").path("nombre").asString());
        assertEquals(1, r.json().get(0).path("pases").size());
        // La atención del otro médico no aparece.
        assertTrue(!r.cuerpo().contains("Afeccion ajena"), r.cuerpo());
    }

    private int atencionesDelPaciente(String paciente) {
        Respuesta r = get("/api/medico/atenciones?fechaDesde=2026-10-01&fechaHasta=2026-10-31"
                + "&paciente=" + paciente, tokenMedico());
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json().size();
    }

    @Test
    void filtraPorPacienteIgnorandoTildesYMayusculas() {
        sembrarAtencion(idMedico, idSocio1, idEspecialidad,
                LocalDate.of(2026, 10, 20), "Afeccion tilde");
        jdbc.update("UPDATE persona SET apellido = 'Pérez' WHERE ci = ?", ciSocio1);

        assertEquals(1, atencionesDelPaciente("per"));
        assertEquals(1, atencionesDelPaciente("perez"));
        assertEquals(1, atencionesDelPaciente("p%C3%A9rez"));
        assertEquals(1, atencionesDelPaciente("P%C3%89REZ"));

        jdbc.update("UPDATE persona SET apellido = 'Perez' WHERE ci = ?", ciSocio1);

        assertEquals(1, atencionesDelPaciente("p%C3%A9rez"));
        assertEquals(0, atencionesDelPaciente("perezz"));
    }

    @Test
    void filtraPorPacienteConCiOApellido() {
        sembrarAtenciones();
        String base = "/api/medico/atenciones?fechaDesde=2026-10-01&fechaHasta=2026-10-31";

        Respuesta porCi = get(base + "&paciente=" + ciSocio1, tokenMedico());
        assertEquals(200, porCi.estado(), porCi.cuerpo());
        assertEquals(1, porCi.json().size());
        assertEquals("Afeccion uno", porCi.json().get(0).path("afeccion").asString());

        Respuesta porApellido = get(base + "&paciente=socia", tokenMedico());
        assertEquals(1, porApellido.json().size());
        assertEquals("Socia",
                porApellido.json().get(0).path("paciente").path("apellido").asString());
    }

    @Test
    void filtraPorEspecialidadYCombinaFiltros() {
        sembrarAtenciones();
        String base = "/api/medico/atenciones?fechaDesde=2026-10-01&fechaHasta=2026-10-31";

        Respuesta porEspecialidad = get(base + "&especialidadId=" + idEspecialidadConPase,
                tokenMedico());
        assertEquals(1, porEspecialidad.json().size());
        assertEquals("Afeccion dos", porEspecialidad.json().get(0).path("afeccion").asString());

        Respuesta combinado = get(base + "&especialidadId=" + idEspecialidadConPase
                + "&paciente=" + ciSocio2, tokenMedico());
        assertEquals(1, combinado.json().size());

        Respuesta sinCruce = get(base + "&especialidadId=" + idEspecialidadConPase
                + "&paciente=" + ciSocio1, tokenMedico());
        assertEquals(0, sinCruce.json().size());
    }

    @Test
    void ordenaPorApellidoDelPaciente() {
        sembrarAtenciones();

        Respuesta r = get("/api/medico/atenciones?fechaDesde=2026-10-01&fechaHasta=2026-10-31"
                + "&orden=apellido", tokenMedico());

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("Soca", r.json().get(0).path("paciente").path("apellido").asString());
        assertEquals("Socia", r.json().get(1).path("paciente").path("apellido").asString());
    }

    @Test
    void validaFechasYOrdenamientos() {
        String medico = tokenMedico();
        assertEquals(400, get("/api/medico/atenciones", medico).estado());
        assertEquals(400, get("/api/medico/atenciones?fechaDesde=2026-10-01", medico).estado());
        assertEquals(400, get("/api/medico/atenciones?fechaDesde=31/10&fechaHasta=2026-10-31",
                medico).estado());
        assertEquals(400, get("/api/medico/atenciones?fechaDesde=2026-10-31"
                + "&fechaHasta=2026-10-01", medico).estado());
        Respuesta orden = get("/api/medico/atenciones?fechaDesde=2026-10-01"
                + "&fechaHasta=2026-10-31&orden=ci", medico);
        assertEquals(400, orden.estado());
        assertEquals("ORDEN_INVALIDO", orden.codigo());
        Respuesta sentido = get("/api/medico/atenciones?fechaDesde=2026-10-01"
                + "&fechaHasta=2026-10-31&sentido=diagonal", medico);
        assertEquals(400, sentido.estado());
        assertEquals("SENTIDO_INVALIDO", sentido.codigo());
    }

    @Test
    void rangoSinResultadosDevuelveListaVacia() {
        sembrarAtenciones();

        Respuesta r = get("/api/medico/atenciones?fechaDesde=2026-11-01&fechaHasta=2026-11-30",
                tokenMedico());

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().size());
    }

    @Test
    void detallePropioCompletoYAjenoNoEncontrado() {
        sembrarAtenciones();
        long propia = jdbc.queryForObject(
                "SELECT id_atencion FROM atencion WHERE afeccion = 'Afeccion dos'",
                Long.class);
        long ajena = jdbc.queryForObject(
                "SELECT id_atencion FROM atencion WHERE afeccion = 'Afeccion ajena'",
                Long.class);

        Respuesta r = get("/api/medico/atenciones/" + propia, tokenMedico());
        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("Afeccion dos", r.json().path("afeccion").asString());
        assertEquals(ciSocio2, r.json().path("paciente").path("ci").asString());
        assertEquals(1, r.json().path("pases").size());

        Respuesta rAjena = get("/api/medico/atenciones/" + ajena, tokenMedico());
        assertEquals(404, rAjena.estado(), rAjena.cuerpo());
        assertEquals("NO_ENCONTRADO", rAjena.codigo());
    }

    @Test
    void seguridadSinTokenYRolIncorrecto() {
        String ruta = "/api/medico/atenciones?fechaDesde=2026-10-01&fechaHasta=2026-10-31";
        assertEquals(401, get(ruta, null).estado());
        assertEquals(403, get(ruta, tokenSocio(ciSocio1)).estado());
        assertEquals(403, get(ruta, tokenEmpleado(ciFuncionario)).estado());
        assertEquals(401, get("/api/medico/atenciones/1", null).estado());
        assertEquals(403, get("/api/medico/atenciones/1", tokenSocio(ciSocio1)).estado());
    }
}
