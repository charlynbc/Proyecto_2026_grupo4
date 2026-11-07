package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-42 a RF-44: HTTP, seguridad y consultas SQL sobre PostgreSQL 17 aislado. */
class EstadisticasAdicionalesIT extends BaseIntegracionIT {
    private static final String PERIODO = "?desde=2026-03-01&hasta=2026-03-31";

    private long consulta(String fecha, String hora, long especialidad, long socio, String estado,
            Long pase) {
        long patron = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                + " VALUES (?, ?, ?, ?, 1, DATE '2026-01-01', DATE '2099-12-31')"
                + " RETURNING id_turno_semanal", Long.class,
                idMedico, especialidad, idConsultorio, idFuncionario);
        long semanal = jdbc.queryForObject(
                "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                + " VALUES (?, 1, ?::time, (?::time + interval '20 minutes')::time)"
                + " RETURNING id_numero_semanal", Long.class, patron, hora, hora);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha)"
                + " VALUES (?, ?, ?::date) RETURNING id_turno", Long.class,
                patron, idConsultorio, fecha);
        long numero = jdbc.queryForObject(
                "INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                + " VALUES (?, ?, 1, ?::time, (?::time + interval '20 minutes')::time)"
                + " RETURNING id_numero", Long.class, turno, semanal, hora, hora);
        if (estado.equals("ATENDIDA") || estado.equals("NO_SE_PRESENTO")) {
            return jdbc.queryForObject(
                    "INSERT INTO consulta (id_socio, id_numero, id_pase, estado, agendada_en,"
                    + " resultado_registrado_por, fecha_resultado)"
                    + " VALUES (?, ?, ?, ?, TIMESTAMPTZ '2026-02-01 10:00:00-03', ?,"
                    + " TIMESTAMPTZ '2026-03-10 12:00:00-03') RETURNING id_consulta",
                    Long.class, socio, numero, pase, estado, idMedico);
        }
        if (estado.startsWith("CANCELADA")) {
            return jdbc.queryForObject(
                    "INSERT INTO consulta (id_socio, id_numero, id_pase, estado, agendada_en,"
                    + " cancelada_por, cancelada_en, motivo_cancelacion)"
                    + " VALUES (?, ?, ?, ?, TIMESTAMPTZ '2026-02-01 10:00:00-03', ?,"
                    + " TIMESTAMPTZ '2026-02-02 10:00:00-03', ?)"
                    + " RETURNING id_consulta", Long.class, socio, numero, pase, estado,
                    idFuncionario, estado.equals("CANCELADA_INSTITUCION") ? "Suspension" : null);
        }
        return jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, id_pase, estado, agendada_en)"
                + " VALUES (?, ?, ?, 'AGENDADA', TIMESTAMPTZ '2026-02-01 10:00:00-03')"
                + " RETURNING id_consulta", Long.class, socio, numero, pase);
    }

    private JsonNode admin(String ruta) {
        Respuesta respuesta = get(ruta, tokenEmpleado(ciAdmin));
        assertEquals(200, respuesta.estado(), respuesta.cuerpo());
        return respuesta.json();
    }

    private long pase(long especialidadOrigen, long destino, String vencimiento) {
        long origen = consulta("2026-03-10", "08:00", especialidadOrigen, idSocio1,
                "ATENDIDA", null);
        long atencion = jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion)"
                + " VALUES (?, ?, 'Control') RETURNING id_atencion",
                Long.class, origen, idMedico);
        return jdbc.queryForObject(
                "INSERT INTO pase (id_atencion, id_especialidad_destino, emitido_en, vence_el)"
                + " VALUES (?, ?, TIMESTAMPTZ '2026-03-10 12:00:00-03', ?::date)"
                + " RETURNING id_pase", Long.class, atencion, destino, vencimiento);
    }

    @Test
    void rf42AgrupaEstadosEfectivosExcluyeCanceladasYDiaActual() {
        consulta("2026-03-10", "10:00", idEspecialidad, idSocio1, "AGENDADA", null);
        consulta("2026-03-10", "10:30", idEspecialidad, idSocio2, "AGENDADA", null);
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha)"
                + " VALUES (?, ?, DATE '2026-03-10')", idSocio2, idFuncionario);
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha)"
                + " VALUES (?, ?, DATE '2026-03-10')", idSocio3, idFuncionario);
        consulta("2026-03-10", "11:00", idEspecialidad, idSocio3, "NO_SE_PRESENTO", null);
        consulta("2026-03-10", "11:30", idEspecialidad, idSocio4, "ATENDIDA", null);
        consulta("2026-03-10", "12:00", idEspecialidad, idSocio1, "CANCELADA_SOCIO", null);
        consulta("2026-03-10", "12:30", idEspecialidadConPase, idSocio1, "AGENDADA", null);

        JsonNode items = admin("/api/estadisticas/inasistencias" + PERIODO).path("items");
        assertEquals(2, items.size());
        assertEquals(idEspecialidadConPase, items.get(0).path("id").asLong());
        JsonNode fila = items.get(1);
        assertEquals(4, fila.path("total").asLong());
        assertEquals(1, fila.path("atendidas").asLong());
        assertEquals(1, fila.path("noAsistio").asLong());
        assertEquals(1, fila.path("noSePresento").asLong());
        assertEquals(1, fila.path("noAtendidas").asLong());
        assertEquals(50, fila.path("porcentajeInasistencia").asDouble());
        JsonNode porMedico = admin("/api/estadisticas/inasistencias" + PERIODO
                + "&agruparPor=MEDICO");
        assertEquals("MEDICO", porMedico.path("agruparPor").asText());
        assertEquals(1, porMedico.path("items").size());
        assertEquals(5, porMedico.path("items").get(0).path("total").asLong());
        assertEquals(60, porMedico.path("items").get(0).path("porcentajeInasistencia").asDouble());
    }

    @Test
    void rf43CuentaPaseDevueltoYCalculaSobreResueltos() {
        long utilizado = pase(idEspecialidad, idEspecialidadConPase, "2026-04-01");
        long disponible = pase(idEspecialidad, idEspecialidadConPase, "2099-12-31");
        pase(idEspecialidad, idEspecialidadConPase, "2026-04-01");
        consulta("2026-03-15", "09:00", idEspecialidadConPase, idSocio1,
                "AGENDADA", utilizado);
        consulta("2026-03-15", "09:30", idEspecialidadConPase, idSocio2,
                "CANCELADA_SOCIO", disponible);
        JsonNode items = admin("/api/estadisticas/pases" + PERIODO
                + "&especialidadOrigenId=" + idEspecialidad).path("items");
        JsonNode fila = null;
        for (JsonNode item : items) {
            if (item.path("especialidadDestino").path("id").asLong() == idEspecialidadConPase) {
                fila = item;
            }
        }
        assertEquals(3, fila.path("emitidos").asLong());
        assertEquals(1, fila.path("utilizados").asLong());
        assertEquals(1, fila.path("disponibles").asLong());
        assertEquals(1, fila.path("vencidos").asLong());
        assertEquals(50, fila.path("porcentajeUtilizados").asDouble());
    }

    @Test
    void rf44CuentaCadaConsultaDeUnAvisoYUsaSuHoraLocal() {
        consulta("2026-03-10", "10:15", idEspecialidad, idSocio1, "AGENDADA", null);
        consulta("2026-03-10", "11:30", idEspecialidad, idSocio1, "ATENDIDA", null);
        consulta("2026-03-10", "12:00", idEspecialidad, idSocio1, "CANCELADA_SOCIO", null);
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha, registrada_en)"
                + " VALUES (?, ?, DATE '2026-03-10', TIMESTAMPTZ '2026-03-10 09:10:00-03')",
                idSocio1, idFuncionario);
        JsonNode consultas = admin("/api/estadisticas/franjas" + PERIODO).path("celdas");
        JsonNode llegadas = admin("/api/estadisticas/franjas" + PERIODO
                + "&vista=LLEGADAS").path("celdas");
        assertEquals(168, consultas.size());
        assertEquals(1, cantidad(consultas, 2, 10));
        assertEquals(1, cantidad(consultas, 2, 11));
        assertEquals(0, cantidad(consultas, 2, 12));
        assertEquals(2, cantidad(llegadas, 2, 9));
    }

    private long cantidad(JsonNode celdas, int dia, int hora) {
        for (JsonNode celda : celdas) {
            if (celda.path("diaSemana").asInt() == dia && celda.path("hora").asInt() == hora) {
                return celda.path("cantidad").asLong();
            }
        }
        throw new AssertionError("Falta la celda");
    }

    @Test
    void rutasRequierenAdministradorYValidanFiltros() {
        for (String ruta : new String[] {"/inasistencias", "/pases", "/franjas"}) {
            assertEquals(401, get("/api/estadisticas" + ruta, null).estado());
            assertEquals(403, get("/api/estadisticas" + ruta, tokenSocio(ciSocio1)).estado());
        }
        assertEquals(400, get("/api/estadisticas/inasistencias?agruparPor=otro",
                tokenEmpleado(ciAdmin)).estado());
        assertEquals(400, get("/api/estadisticas/franjas?vista=otro",
                tokenEmpleado(ciAdmin)).estado());
        assertEquals(400, get("/api/estadisticas/pases?especialidadOrigenId=0",
                tokenEmpleado(ciAdmin)).estado());
        assertEquals(400, get("/api/estadisticas/pases?especialidadOrigenId=abc",
                tokenEmpleado(ciAdmin)).estado());
    }
}
