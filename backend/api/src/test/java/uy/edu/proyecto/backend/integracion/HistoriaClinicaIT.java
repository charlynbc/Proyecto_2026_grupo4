package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;

/** RF-12 contra PostgreSQL real: propiedad, filtros, orden, detalle, pases y seguridad. */
class HistoriaClinicaIT extends BaseIntegracionIT {

    private long idMedico2;
    private long idNutricion;

    private long a1; // socio1, hace 30 dias, Medicina General, medico 1, sin pases
    private long a2; // socio1, hace 10 dias, Cardiologia, medico 2, dos pases
    private long a3; // socio1, hace 2 dias 23:30, Medicina General, medico 1, sin tratamiento ni observaciones
    private long b1; // socio2, hace 5 dias, Medicina General, medico 1

    @BeforeEach
    void sembrarHistoria() {
        jdbc.update("INSERT INTO persona VALUES (?, 'Marta', 'Moreira', DATE '1980-01-01')", ci(1000009));
        idMedico2 = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, primer_ingreso_completado)"
                        + " VALUES (?, 'MEDICO', 'm2@ejemplo.invalid', '099111333', false)"
                        + " RETURNING id_cuenta", Long.class, ci(1000009));
        idNutricion = jdbc.queryForObject(
                "INSERT INTO especialidad (nombre, requiere_pase) VALUES ('Nutricion', true)"
                        + " RETURNING id_especialidad", Long.class);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?) ON CONFLICT DO NOTHING",
                idMedico, idEspecialidadConPase);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?) ON CONFLICT DO NOTHING",
                idMedico2, idEspecialidadConPase);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?) ON CONFLICT DO NOTHING",
                idMedico2, idEspecialidad);

        a1 = atencion(idSocio1, hoy().minusDays(30), LocalTime.of(10, 0), idEspecialidad, idMedico,
                "Gripe", "Reposo e hidratacion", "Controlar fiebre");
        a2 = atencion(idSocio1, hoy().minusDays(10), LocalTime.of(10, 0), idEspecialidadConPase, idMedico2,
                "Hipertension", "Medicacion antihipertensiva 100% diaria", "Volver en un mes");
        a3 = atencion(idSocio1, hoy().minusDays(2), LocalTime.of(23, 30), idEspecialidad, idMedico,
                "Control", null, null);
        b1 = atencion(idSocio2, hoy().minusDays(5), LocalTime.of(10, 0), idEspecialidad, idMedico,
                "Dolor lumbar", "Tratamiento reservado del otro socio", "Observacion privada");

        pase(a2, idNutricion, hoy().plusDays(20));
        pase(a2, idEspecialidad, hoy().plusDays(60));
    }

    private long atencion(long socio, LocalDate fecha, LocalTime hora, long especialidad, long medico,
            String afeccion, String tratamiento, String observaciones) {
        long turno = sembrarTurno(fecha, 1);
        jdbc.update("UPDATE turno_semanal SET id_especialidad = ?, id_medico = ? WHERE id_turno_semanal ="
                + " (SELECT id_turno_semanal FROM turno WHERE id_turno = ?)", especialidad, medico, turno);
        long consulta = jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero, estado, resultado_registrado_por,"
                        + " fecha_resultado) VALUES (?, ?, 'ATENDIDA', ?, now()) RETURNING id_consulta",
                Long.class, socio, numeroId(turno, 1), medico);
        return jdbc.queryForObject(
                "INSERT INTO atencion (id_consulta, id_medico, afeccion, tratamiento, observaciones,"
                        + " registrada_en) VALUES (?, ?, ?, ?, ?, ?) RETURNING id_atencion",
                Long.class, consulta, medico, afeccion, tratamiento, observaciones,
                fecha.atTime(hora).atZone(ZONA).toOffsetDateTime());
    }

    private void pase(long atencion, long destino, LocalDate vence) {
        jdbc.update("INSERT INTO pase (id_atencion, id_especialidad_destino, emitido_en, vence_el)"
                + " SELECT ?, ?, registrada_en, ? FROM atencion WHERE id_atencion = ?",
                atencion, destino, vence, atencion);
    }

    private JsonNode listar(String token, String consulta) {
        Respuesta r = get("/api/historia-clinica" + consulta, token);
        assertEquals(200, r.estado(), r.cuerpo());
        return r.json();
    }

    private List<Long> ids(JsonNode lista) {
        List<Long> ids = new ArrayList<>();
        lista.forEach(n -> ids.add(n.path("idAtencion").asLong()));
        return ids;
    }

    private void inactivar(long idCuenta) {
        jdbc.update("UPDATE cuenta SET habilitada = FALSE, ultimo_inactivador = ?,"
                + " ultima_inactivacion_en = CURRENT_TIMESTAMP WHERE id_cuenta = ?", idAdmin, idCuenta);
    }

    @Test
    void cadaSocioVeSoloSuHistoriaOrdenadaPorFechaDescendente() {
        JsonNode propia = listar(tokenSocio(ciSocio1), "");
        JsonNode ajena = listar(tokenSocio(ciSocio2), "");

        assertEquals(List.of(a3, a2, a1), ids(propia));
        assertEquals(List.of(b1), ids(ajena));
        assertFalse(propia.toString().contains("Tratamiento reservado del otro socio"));
        assertFalse(ajena.toString().contains("Medicacion antihipertensiva"));
    }

    @Test
    void socioSinAtencionesRecibeListaVacia() {
        JsonNode lista = listar(tokenSocio(ciSocio3), "");

        assertTrue(lista.isArray());
        assertEquals(0, lista.size());
    }

    @Test
    void unSocioIdEnLaConsultaNoSustituyeLaIdentidadDelToken() {
        JsonNode lista = listar(tokenSocio(ciSocio1), "?socioId=" + idSocio2 + "&idSocio=" + idSocio2);

        assertEquals(List.of(a3, a2, a1), ids(lista));
    }

    @Test
    void atencionAjenaOInexistenteDevuelve404IgualSinFiltrarDatosClinicos() {
        String intruso = tokenSocio(ciSocio2);

        Respuesta ajena = get("/api/historia-clinica/" + a2, intruso);
        Respuesta inexistente = get("/api/historia-clinica/999999", intruso);

        assertEquals(404, ajena.estado());
        assertEquals("HISTORIA_NO_ENCONTRADA", ajena.codigo());
        assertEquals(404, inexistente.estado());
        assertEquals(inexistente.cuerpo(), ajena.cuerpo());
        assertFalse(ajena.cuerpo().contains("Hipertension"));
        assertFalse(ajena.cuerpo().contains("Medicacion"));
    }

    @Test
    void filtrosPorFechaSonInclusivosYUsanElDiaDeMontevideo() {
        String socio = tokenSocio(ciSocio1);

        // a3 se registro a las 23:30 de Montevideo: su dia es hoy-2 aunque en UTC ya sea hoy-1.
        assertEquals(List.of(a3), ids(listar(socio,
                "?fechaDesde=" + hoy().minusDays(2) + "&fechaHasta=" + hoy().minusDays(2))));
        assertEquals(hoy().minusDays(2).toString(),
                get("/api/historia-clinica/" + a3, socio).json().path("fechaAtencion").asString());
        assertEquals(List.of(a3, a2), ids(listar(socio, "?fechaDesde=" + hoy().minusDays(10))));
        assertEquals(List.of(a2, a1), ids(listar(socio, "?fechaHasta=" + hoy().minusDays(10))));
        assertEquals(List.of(), ids(listar(socio,
                "?fechaDesde=" + hoy().minusDays(9) + "&fechaHasta=" + hoy().minusDays(3))));
    }

    @Test
    void busquedaPorTratamientoIgnoraTildes() {
        String socio = tokenSocio(ciSocio1);
        jdbc.update("UPDATE atencion SET tratamiento = 'Indicación del doctor Pérez'"
                + " WHERE id_atencion = ?", a1);
        jdbc.update("UPDATE atencion SET tratamiento = 'Control con la doctora Perez'"
                + " WHERE id_atencion = ?", a2);

        assertEquals(List.of(a2, a1), ids(listar(socio, "?texto=per")));
        assertEquals(List.of(a2, a1), ids(listar(socio, "?texto=perez")));
        assertEquals(List.of(a2, a1), ids(listar(socio, "?texto=p%C3%A9rez")));
        assertEquals(List.of(a2, a1), ids(listar(socio, "?texto=P%C3%89REZ")));
        assertEquals(List.of(a1), ids(listar(socio, "?texto=indicacion")));
        assertEquals(List.of(a1), ids(listar(socio, "?texto=INDICACI%C3%93N")));
    }

    @Test
    void filtrosPorEspecialidadYMedico() {
        String socio = tokenSocio(ciSocio1);

        assertEquals(List.of(a2), ids(listar(socio, "?especialidadId=" + idEspecialidadConPase)));
        assertEquals(List.of(a3, a1), ids(listar(socio, "?especialidadId=" + idEspecialidad)));
        assertEquals(List.of(a2), ids(listar(socio, "?medicoId=" + idMedico2)));
        assertEquals(List.of(a3, a1), ids(listar(socio, "?medicoId=" + idMedico)));
        assertEquals(List.of(), ids(listar(socio, "?especialidadId=" + idNutricion)));
    }

    @Test
    void busquedaPorTratamientoIgnoraMayusculasYTrataLosComodinesComoTexto() {
        String socio = tokenSocio(ciSocio1);

        assertEquals(List.of(a1), ids(listar(socio, "?texto=HIDRATACION")));
        assertEquals(List.of(a2), ids(listar(socio, "?texto=100%25")));
        assertEquals(List.of(a2), ids(listar(socio, "?texto=%25")));
        assertEquals(List.of(), ids(listar(socio, "?texto=_____")));
        assertEquals(List.of(), ids(listar(socio, "?texto=reservado")),
                "No debe encontrar el tratamiento de otro socio");
        // Las atenciones sin tratamiento nunca coinciden con un texto.
        assertEquals(List.of(), ids(listar(socio, "?texto=Control")));
    }

    @Test
    void losFiltrosSeCombinan() {
        String socio = tokenSocio(ciSocio1);

        assertEquals(List.of(a1), ids(listar(socio, "?especialidadId=" + idEspecialidad
                + "&medicoId=" + idMedico + "&texto=reposo&fechaHasta=" + hoy().minusDays(20))));
        assertEquals(List.of(), ids(listar(socio, "?especialidadId=" + idEspecialidadConPase
                + "&medicoId=" + idMedico)));
        assertEquals(List.of(a2), ids(listar(socio, "?especialidadId=" + idEspecialidadConPase
                + "&fechaDesde=" + hoy().minusDays(11) + "&fechaHasta=" + hoy().minusDays(9)
                + "&medicoId=" + idMedico2 + "&texto=antihipertensiva")));
    }

    @Test
    void ordenPorFechaYEspecialidadEnAmbosSentidos() {
        String socio = tokenSocio(ciSocio1);

        assertEquals(List.of(a1, a2, a3), ids(listar(socio, "?orden=fecha_atencion&sentido=asc")));
        assertEquals(List.of(a1, a2, a3), ids(listar(socio, "?orden=fecha&sentido=asc")));
        assertEquals(List.of(a2, a1, a3), ids(listar(socio, "?orden=especialidad&sentido=asc")));
        assertEquals(List.of(a3, a1, a2), ids(listar(socio, "?orden=especialidad&sentido=desc")));
    }

    @Test
    void listadoNoDuplicaAtencionesConVariosPases() {
        JsonNode lista = listar(tokenSocio(ciSocio1), "");

        assertEquals(3, lista.size());
        assertEquals(2, lista.get(1).path("pases").size());
        assertEquals(0, lista.get(0).path("pases").size());
    }

    @Test
    void detalleCompletoConPasesYVigenciaOriginal() {
        JsonNode d = get("/api/historia-clinica/" + a2, tokenSocio(ciSocio1)).json();

        assertEquals(a2, d.path("idAtencion").asLong());
        assertEquals(hoy().minusDays(10).toString(), d.path("fechaAtencion").asString());
        assertEquals(idMedico2, d.path("medicoId").asLong());
        assertEquals("Marta", d.path("medicoNombre").asString());
        assertEquals("Moreira", d.path("medicoApellido").asString());
        assertEquals("Cardiologia", d.path("especialidad").path("nombre").asString());
        assertEquals("Hipertension", d.path("afeccion").asString());
        assertEquals("Medicacion antihipertensiva 100% diaria", d.path("tratamiento").asString());
        assertEquals("Volver en un mes", d.path("observaciones").asString());
        JsonNode pases = d.path("pases");
        assertEquals(2, pases.size());
        // Orden: el que vence mas tarde primero.
        assertEquals("Medicina General", pases.get(0).path("especialidad").path("nombre").asString());
        assertEquals(hoy().plusDays(60).toString(), pases.get(0).path("venceEl").asString());
        assertEquals("Nutricion", pases.get(1).path("especialidad").path("nombre").asString());
        assertEquals(hoy().plusDays(20).toString(), pases.get(1).path("venceEl").asString());
        assertFalse(pases.get(0).path("emitidoEn").isMissingNode());
    }

    @Test
    void detalleSinPasesNiCamposOpcionales() {
        JsonNode d = get("/api/historia-clinica/" + a3, tokenSocio(ciSocio1)).json();

        assertEquals("Control", d.path("afeccion").asString());
        assertTrue(d.path("tratamiento").isNull());
        assertTrue(d.path("observaciones").isNull());
        assertEquals(0, d.path("pases").size());
    }

    @Test
    void lasVigenciasDeLosPasesNoCambianConElPasoDelTiempo() {
        // Un pase ya vencido se sigue mostrando con su fecha original.
        jdbc.update("UPDATE pase SET vence_el = ? WHERE id_atencion = ? AND id_especialidad_destino = ?",
                hoy().minusDays(1), a2, idNutricion);

        JsonNode d = get("/api/historia-clinica/" + a2, tokenSocio(ciSocio1)).json();

        assertEquals(2, d.path("pases").size());
        assertEquals(hoy().minusDays(1).toString(), d.path("pases").get(1).path("venceEl").asString());
    }

    @Test
    void parametrosInvalidosDevuelven400() {
        String socio = tokenSocio(ciSocio1);

        for (String consulta : List.of("?fechaDesde=ayer", "?fechaHasta=2026-13-45",
                "?fechaDesde=2026-12-31&fechaHasta=2026-01-01", "?especialidadId=abc", "?medicoId=-1",
                "?orden=password", "?sentido=sideways")) {
            Respuesta r = get("/api/historia-clinica" + consulta, socio);
            assertEquals(400, r.estado(), consulta + " " + r.cuerpo());
        }
        assertEquals("VALIDACION", get("/api/historia-clinica?fechaDesde=ayer", socio).codigo());
        assertEquals("ORDEN_INVALIDO", get("/api/historia-clinica?orden=x", socio).codigo());
        assertEquals("VALIDACION", get("/api/historia-clinica/abc", socio).codigo());
        assertEquals(400, get("/api/historia-clinica/0", socio).estado());
    }

    @Test
    void textoConInyeccionSqlSeTrataComoTexto() {
        String socio = tokenSocio(ciSocio1);

        Respuesta r = get("/api/historia-clinica?texto=%27%3B%20DROP%20TABLE%20atencion%3B--", socio);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().size());
        assertEquals(4, contar("atencion"));
    }

    @Test
    void sinTokenOConRolDistintoDeSocioNoAccede() {
        for (String ruta : List.of("/api/historia-clinica", "/api/historia-clinica/" + a1)) {
            assertEquals(401, get(ruta, null).estado());
            assertEquals(403, get(ruta, tokenEmpleado(ciFuncionario)).estado());
            assertEquals(403, get(ruta, tokenEmpleado(ciMedico)).estado());
            assertEquals(403, get(ruta, tokenEmpleado(ciAdmin)).estado());
        }
    }

    @Test
    void unSocioInactivadoNoPuedeUsarSuTokenAnterior() {
        String token = tokenSocio(ciSocio1);
        assertEquals(200, get("/api/historia-clinica", token).estado());

        inactivar(idSocio1);

        Respuesta lista = get("/api/historia-clinica", token);
        Respuesta detalle = get("/api/historia-clinica/" + a1, token);
        assertEquals(401, lista.estado());
        assertEquals(401, detalle.estado());
        assertFalse(lista.cuerpo().contains("Reposo"));
        assertFalse(detalle.cuerpo().contains("Reposo"));
    }

    @Test
    void laConsultaDeHistoriaNoModificaDatos() {
        int atenciones = contar("atencion");
        int pases = contar("pase");

        listar(tokenSocio(ciSocio1), "?orden=especialidad");
        get("/api/historia-clinica/" + a2, tokenSocio(ciSocio1));

        assertEquals(atenciones, contar("atencion"));
        assertEquals(pases, contar("pase"));
    }
}
