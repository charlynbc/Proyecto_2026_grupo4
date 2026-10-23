package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** RF-16, RF-18, RF-21 y RF-23 contra PostgreSQL real. Los datos "de hoy" se siembran en la base efimera. */
class LlegadaAgendaMedicoIT extends BaseIntegracionIT {

    private long turnoHoy;
    private long consulta1;
    private long consulta2;

    private void sembrarJornada() {
        turnoHoy = sembrarTurno(hoy(), 2);
        consulta1 = sembrarConsulta(idSocio1, numeroId(turnoHoy, 1));
        consulta2 = sembrarConsulta(idSocio2, numeroId(turnoHoy, 2));
    }

    private Respuesta resultado(String token, long consulta, String cuerpo) {
        return post("/api/medico/consultas/" + consulta + "/resultado", token, cuerpo);
    }

    @Test
    void rf16RegistraLlegadaDeFormaIdempotenteYRechazaSinConsultaDeHoy() {
        sembrarJornada();
        String funcionario = tokenEmpleado(ciFuncionario);

        Respuesta hoyItems = get("/api/avisos-llegada/consultas-hoy?ci=" + ciSocio1, funcionario);
        assertEquals(200, hoyItems.estado());
        assertEquals(1, hoyItems.json().path("items").size());

        Respuesta primera = post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));
        assertEquals(201, primera.estado(), primera.cuerpo());
        Respuesta segunda = post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));
        assertEquals(200, segunda.estado(), "Un segundo aviso devuelve el original");
        assertEquals(1, contar("aviso_llegada"));
        assertEquals(idFuncionario, jdbc.queryForObject(
                "SELECT id_funcionario FROM aviso_llegada", Long.class));

        Respuesta sinConsulta = post("/api/avisos-llegada", funcionario,
                "{\"ci\":\"%s\"}".formatted(ciSocio3));
        assertEquals(409, sinConsulta.estado());
        assertEquals("SIN_CONSULTAS_AGENDADAS", sinConsulta.codigo());
        assertEquals(1, contar("aviso_llegada"));
    }

    @Test
    void rf16ConflictoDeInteresCuandoElFuncionarioEsElMismoSocio() {
        sembrarJornada();
        String hash = jdbc.queryForObject(
                "SELECT contrasena_hash FROM cuenta WHERE id_cuenta = ?", String.class, idFuncionario);
        jdbc.update("INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                + " primer_ingreso_completado) VALUES (?, 'FUNCIONARIO', 'doble@ejemplo.invalid',"
                + " '099000111', 'Calle 1', ?, true)", ciSocio1, hash);
        String funcionarioSocio = tokenEmpleado(ciSocio1);

        Respuesta r = post("/api/avisos-llegada", funcionarioSocio, "{\"ci\":\"%s\"}".formatted(ciSocio1));
        assertEquals(403, r.estado());
        assertEquals("CONFLICTO_INTERES", r.codigo());
        assertEquals(0, contar("aviso_llegada"));
    }

    @Test
    void rf18ConsultaAgendasConFiltrosYMarcaLlegada() {
        sembrarJornada();
        String funcionario = tokenEmpleado(ciFuncionario);
        post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));

        Respuesta todas = get("/api/agendas?fecha=" + hoy(), funcionario);
        assertEquals(200, todas.estado(), todas.cuerpo());
        assertEquals(2, todas.json().path("items").size());

        Respuesta conLlegada = get("/api/agendas?fecha=" + hoy() + "&llegada=true", funcionario);
        assertEquals(1, conLlegada.json().path("items").size());
        assertEquals(consulta1, conLlegada.json().path("items").get(0).path("consultaId").asLong());
        assertNotNull(conLlegada.json().path("items").get(0).path("llegadaEn").asString());

        Respuesta porCi = get("/api/agendas?ci=" + ciSocio2, funcionario);
        assertEquals(1, porCi.json().path("items").size());
        assertEquals(consulta2, porCi.json().path("items").get(0).path("consultaId").asLong());

        assertEquals(400, get("/api/agendas?estado=INVENTADO", funcionario).estado());
        assertEquals(400, get("/api/agendas?size=101", funcionario).estado());
    }

    @Test
    void rf21MedicoVeSusTurnosYNumerosConSusReservas() {
        sembrarJornada();
        String medico = tokenEmpleado(ciMedico);

        Respuesta turnos = get("/api/medico/turnos?fecha=" + hoy(), medico);
        assertEquals(200, turnos.estado(), turnos.cuerpo());
        assertEquals(1, turnos.json().path("items").size());
        assertEquals(2, turnos.json().path("items").get(0).path("cantidadReservados").asInt());

        Respuesta numeros = get("/api/medico/turnos/" + turnoHoy + "/numeros", medico);
        assertEquals(200, numeros.estado(), numeros.cuerpo());
        assertEquals(2, numeros.json().path("items").size());
    }

    @Test
    void rf23RegistraResultadosYRechazaLosInvalidos() {
        sembrarJornada();
        String funcionario = tokenEmpleado(ciFuncionario);
        String medico = tokenEmpleado(ciMedico);

        Respuesta sinAviso = resultado(medico, consulta1, "{\"resultado\":\"NO_SE_PRESENTO\"}");
        assertTrue(sinAviso.estado() >= 400 && sinAviso.estado() < 500, "estado " + sinAviso.estado());
        assertEquals("SIN_AVISO_LLEGADA", sinAviso.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta1));

        post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));

        Respuesta sinAfeccion = resultado(medico, consulta1, "{\"resultado\":\"ATENDIDA\"}");
        assertEquals(400, sinAfeccion.estado());
        assertEquals("AGENDADA", estadoConsulta(consulta1));

        Respuesta noSePresentoConDatos = resultado(medico, consulta1,
                "{\"resultado\":\"NO_SE_PRESENTO\",\"afeccion\":\"Gripe\"}");
        assertEquals(400, noSePresentoConDatos.estado());
        assertEquals("AGENDADA", estadoConsulta(consulta1));

        Respuesta atendida = resultado(medico, consulta1, """
                {"resultado":"ATENDIDA","afeccion":"Gripe","tratamiento":"Reposo","observaciones":"Sin novedades",
                 "pases":[{"especialidadDestinoId":%d,"vigenciaDias":30}]}
                """.formatted(idEspecialidadConPase));
        assertEquals(200, atendida.estado(), atendida.cuerpo());
        assertEquals("ATENDIDA", estadoConsulta(consulta1));
        assertEquals(1, contar("atencion"));
        assertEquals(1, contar("pase"));

        Respuesta repetido = resultado(medico, consulta1, "{\"resultado\":\"NO_SE_PRESENTO\"}");
        assertTrue(repetido.estado() >= 400 && repetido.estado() < 500, "estado " + repetido.estado());
        assertEquals("ATENDIDA", estadoConsulta(consulta1));
        assertEquals(1, contar("atencion"));

        Respuesta agenda = get("/api/agendas?ci=" + ciSocio1, funcionario);
        assertEquals("ATENDIDA", agenda.json().path("items").get(0).path("estado").asString());
    }

    @Test
    void rf23ConflictoDeInteresCuandoElMedicoEsElMismoSocio() {
        sembrarJornada();
        String hash = jdbc.queryForObject(
                "SELECT contrasena_hash FROM cuenta WHERE id_cuenta = ?", String.class, idMedico);
        long medicoSocio = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, 'MEDICO', 'doble2@ejemplo.invalid',"
                        + " '099000222', 'Calle 1', ?, true) RETURNING id_cuenta",
                Long.class, ciSocio1, hash);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", medicoSocio, idEspecialidad);
        jdbc.update("UPDATE turno_semanal SET id_medico = ?", medicoSocio);
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)",
                idSocio1, idFuncionario, hoy());

        Respuesta r = resultado(tokenEmpleado(ciSocio1), consulta1, "{\"resultado\":\"NO_SE_PRESENTO\"}");
        assertEquals(403, r.estado());
        assertEquals("CONFLICTO_DE_INTERES", r.codigo());
        assertEquals("AGENDADA", estadoConsulta(consulta1));
    }
}
