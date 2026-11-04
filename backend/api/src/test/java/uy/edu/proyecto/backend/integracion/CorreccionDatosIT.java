package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

/**
 * RF-38: correccion administrativa de datos de usuarios, especialidades y
 * consultorios contra PostgreSQL real.
 */
class CorreccionDatosIT extends BaseIntegracionIT {

    private static final String USUARIOS = "/api/usuarios/";
    private static final String ESPECIALIDADES = "/api/especialidades/";
    private static final String CONSULTORIOS = "/api/consultorios/";

    /* ---------- Usuarios ---------- */

    @Test
    void corrigeDatosDePersonaYSeReflejaEnTodasLasCuentas() {
        // La misma persona tiene ademas una cuenta de empleado inactivada.
        jdbc.update("""
                INSERT INTO cuenta (ci, rol, correo, telefono_1, habilitada)
                VALUES (?, 'FUNCIONARIO', ?, '099000000', FALSE)
                """, ciSocio1, "emp" + ciSocio1 + "@ejemplo.invalid");

        Respuesta r = enviar("PATCH", USUARIOS + idSocio1, tokenEmpleado(ciAdmin),
                null, """
                {"nombre":"Sofia Elena","apellido":"Socia Corregida","fechaNacimiento":"1985-06-06"}
                """);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("Sofia Elena", r.json().path("nombre").asString());
        assertEquals("Socia Corregida", r.json().path("apellido").asString());
        assertEquals("1985-06-06", r.json().path("fechaNacimiento").asString());
        assertEquals("SOCIO", r.json().path("rol").asString());

        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta c JOIN persona p ON p.ci = c.ci"
                        + " WHERE p.nombre = 'Sofia Elena'"
                        + " AND p.apellido = 'Socia Corregida'"
                        + " AND p.fecha_nacimiento = DATE '1985-06-06'",
                Integer.class),
                "La correccion de persona vale para las dos cuentas");
    }

    @Test
    void corregirCiPropagaATodasLasCuentasDeLaPersona() {
        jdbc.update("""
                INSERT INTO cuenta (ci, rol, correo, telefono_1, habilitada)
                VALUES (?, 'FUNCIONARIO', ?, '099000000', FALSE)
                """, ciSocio1, "emp" + ciSocio1 + "@ejemplo.invalid");
        String ciNueva = ci(3000001);

        Respuesta r = enviar("PATCH", USUARIOS + idSocio1, tokenEmpleado(ciAdmin),
                null, "{\"ci\":\"" + ciNueva + "\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(ciNueva, r.json().path("ci").asString());
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = ?", Integer.class, ciNueva),
                "Las dos cuentas quedan asociadas a la CI corregida");
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = ?", Integer.class, ciSocio1));
    }

    @Test
    void corrigeContactoDeLaCuenta() {
        Respuesta r = enviar("PATCH", USUARIOS + idSocio1, tokenEmpleado(ciAdmin),
                null, """
                {"correo":"  NUEVO@ejemplo.INVALID  ","telefono1":"099555666",
                 "telefono2":"099555777","direccion":"  Nueva Direccion 1  "}
                """);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("nuevo@ejemplo.invalid", r.json().path("correo").asString());
        assertEquals("099555666", r.json().path("telefono1").asString());
        assertEquals("099555777", r.json().path("telefono2").asString());
        assertEquals("Nueva Direccion 1", r.json().path("direccion").asString());

        Respuesta borrado = enviar("PATCH", USUARIOS + idSocio1,
                tokenEmpleado(ciAdmin), null,
                "{\"telefono2\":null}");

        assertEquals(200, borrado.estado(), borrado.cuerpo());
        assertTrue(borrado.json().path("telefono2").isNull());
        assertNull(jdbc.queryForObject(
                "SELECT telefono_2 FROM cuenta WHERE id_cuenta = ?",
                String.class, idSocio1));
    }

    @Test
    void direccionSeBorraSoloEnCuentasPendientesDePrimerIngreso() {
        // Cuenta pendiente (sin primer ingreso): la direccion es opcional.
        Respuesta pendiente = enviar("PATCH", USUARIOS + idSocioNuevo,
                tokenEmpleado(ciAdmin), null, "{\"direccion\":null}");

        assertEquals(200, pendiente.estado(), pendiente.cuerpo());
        assertTrue(pendiente.json().path("direccion").isNull());

        // Cuenta activada: la direccion no puede quedar vacia (RF-02).
        Respuesta activada = enviar("PATCH", USUARIOS + idSocio1,
                tokenEmpleado(ciAdmin), null, "{\"direccion\":null}");

        assertEquals(400, activada.estado(), activada.cuerpo());
        assertEquals("VALIDACION", activada.codigo());
        assertEquals("Calle Falsa 123", jdbc.queryForObject(
                "SELECT direccion FROM cuenta WHERE id_cuenta = ?",
                String.class, idSocio1),
                "La direccion de la cuenta activada no se borra");
    }

    @Test
    void ciInvalidaDevuelve400() {
        Respuesta r = enviar("PATCH", USUARIOS + idSocio1, tokenEmpleado(ciAdmin),
                null, "{\"ci\":\"12345670\"}");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("CI_INVALIDA", r.codigo());
    }

    @Test
    void ciDeOtraPersonaDevuelve409() {
        Respuesta r = enviar("PATCH", USUARIOS + idSocio1, tokenEmpleado(ciAdmin),
                null, "{\"ci\":\"" + ciSocio2 + "\"}");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("CI_EN_USO", r.codigo());
    }

    @Test
    void rolNoSePuedeCorregir() {
        Respuesta r = enviar("PATCH", USUARIOS + idSocio1, tokenEmpleado(ciAdmin),
                null, "{\"rol\":\"ADMINISTRADOR\"}");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        assertTrue(r.json().path("message").asString().contains("rol"));
        assertEquals("SOCIO", jdbc.queryForObject(
                "SELECT rol FROM cuenta WHERE id_cuenta = ?", String.class, idSocio1));
    }

    @Test
    void cuentaInexistenteDevuelve404() {
        Respuesta r = enviar("PATCH", USUARIOS + 999999, tokenEmpleado(ciAdmin),
                null, "{\"nombre\":\"Nadie\"}");

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("USUARIO_NO_ENCONTRADO", r.codigo());
    }

    @Test
    void especialidadesSoloSeCorrigenEnMedicos() {
        Respuesta r = enviar("PATCH", USUARIOS + idSocio1, tokenEmpleado(ciAdmin),
                null, "{\"especialidadIds\":[" + idEspecialidad + "]}");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
    }

    @Test
    void medicoReemplazaEspecialidadesSinAgenda() {
        Respuesta r = enviar("PATCH", USUARIOS + idMedico, tokenEmpleado(ciAdmin),
                null, "{\"especialidadIds\":[" + idEspecialidadConPase + "]}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("especialidadIds").size());
        assertEquals(idEspecialidadConPase,
                r.json().path("especialidadIds").get(0).asLong());
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM medico_especialidad WHERE id_medico = ?"
                        + " AND id_especialidad = ?",
                Integer.class, idMedico, idEspecialidad));
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM medico_especialidad WHERE id_medico = ?"
                        + " AND id_especialidad = ?",
                Integer.class, idMedico, idEspecialidadConPase));
    }

    @Test
    void noQuitaEspecialidadConTurnoVigente() {
        sembrarTurno(hoy().plusDays(7), 2);

        Respuesta r = enviar("PATCH", USUARIOS + idMedico, tokenEmpleado(ciAdmin),
                null, "{\"especialidadIds\":[" + idEspecialidadConPase + "]}");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("ESPECIALIDAD_EN_USO", r.codigo());
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM medico_especialidad WHERE id_medico = ?"
                        + " AND id_especialidad = ?",
                Integer.class, idMedico, idEspecialidad),
                "La especialidad no se quita");
    }

    @Test
    void historialClinicoSeConservaTrasCorregirAlMedico() {
        long turno = sembrarTurno(hoy().minusDays(7), 1);
        long consulta = sembrarConsulta(idSocio1, numeroId(turno, 1));
        jdbc.update("""
                UPDATE consulta SET estado = 'ATENDIDA', resultado_registrado_por = ?,
                       fecha_resultado = CURRENT_TIMESTAMP WHERE id_consulta = ?
                """, idMedico, consulta);
        jdbc.update("""
                INSERT INTO atencion (id_consulta, id_medico, afeccion, tratamiento)
                VALUES (?, ?, 'Afeccion previa', 'Tratamiento previo')
                """, consulta, idMedico);

        Respuesta r = enviar("PATCH", USUARIOS + idMedico, tokenEmpleado(ciAdmin),
                null, "{\"nombre\":\"Mario Corregido\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("Afeccion previa", jdbc.queryForObject(
                "SELECT afeccion FROM atencion WHERE id_consulta = ?",
                String.class, consulta));
        assertEquals("ATENDIDA", estadoConsulta(consulta));
        assertEquals(idMedico, jdbc.queryForObject(
                "SELECT resultado_registrado_por FROM consulta WHERE id_consulta = ?",
                Long.class, consulta));
    }

    @Test
    void correccionDeUsuariosEsExclusivaDelAdministrador() {
        String cuerpo = "{\"nombre\":\"Nuevo\"}";

        assertEquals(401, enviar("PATCH", USUARIOS + idSocio1, null, null, cuerpo).estado());
        assertEquals(403, enviar("PATCH", USUARIOS + idSocio1,
                tokenSocio(ciSocio1), null, cuerpo).estado());
        assertEquals(403, enviar("PATCH", USUARIOS + idSocio1,
                tokenEmpleado(ciFuncionario), null, cuerpo).estado());
        assertEquals(403, enviar("PATCH", USUARIOS + idMedico,
                tokenEmpleado(ciMedico), null, cuerpo).estado());
        assertEquals("Sofia", jdbc.queryForObject(
                "SELECT nombre FROM persona WHERE ci = ?", String.class, ciSocio1),
                "Los rechazos no modifican la base");
    }

    /* ---------- Especialidades ---------- */

    @Test
    void corrigeNombreYExigenciaDePase() {
        Respuesta r = enviar("PATCH", ESPECIALIDADES + idEspecialidad,
                tokenEmpleado(ciAdmin), null,
                "{\"nombre\":\"Medicina General Corregida\",\"requierePase\":true}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("Medicina General Corregida", r.json().path("nombre").asString());
        assertTrue(r.json().path("requierePase").asBoolean());
        assertEquals("Medicina General Corregida", jdbc.queryForObject(
                "SELECT nombre FROM especialidad WHERE id_especialidad = ?",
                String.class, idEspecialidad));
    }

    @Test
    void nombreDeEspecialidadDuplicadoDevuelve409() {
        Respuesta r = enviar("PATCH", ESPECIALIDADES + idEspecialidad,
                tokenEmpleado(ciAdmin), null, "{\"nombre\":\"CARDIOLOGIA\"}");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("ESPECIALIDAD_DUPLICADA", r.codigo());
    }

    @Test
    void cambioDePaseNoAlteraConsultasYaAgendadas() {
        long turno = sembrarTurno(hoy().plusDays(3), 1);
        long consulta = sembrarConsulta(idSocio1, numeroId(turno, 1));

        Respuesta r = enviar("PATCH", ESPECIALIDADES + idEspecialidad,
                tokenEmpleado(ciAdmin), null, "{\"requierePase\":true}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("AGENDADA", estadoConsulta(consulta));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM consulta WHERE id_consulta = ?"
                        + " AND id_pase IS NOT NULL",
                Integer.class, consulta),
                "La consulta agendada conserva su estado y su contenido");
    }

    @Test
    void especialidadInexistenteDevuelve404() {
        Respuesta r = enviar("PATCH", ESPECIALIDADES + 999999,
                tokenEmpleado(ciAdmin), null, "{\"requierePase\":false}");

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("ESPECIALIDAD_NO_ENCONTRADA", r.codigo());
    }

    @Test
    void correccionDeEspecialidadSinCamposDevuelve400() {
        Respuesta r = enviar("PATCH", ESPECIALIDADES + idEspecialidad,
                tokenEmpleado(ciAdmin), null, "{}");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
    }

    @Test
    void correccionDeEspecialidadesEsExclusivaDelAdministrador() {
        String cuerpo = "{\"requierePase\":false}";

        assertEquals(401, enviar("PATCH", ESPECIALIDADES + idEspecialidad,
                null, null, cuerpo).estado());
        assertEquals(403, enviar("PATCH", ESPECIALIDADES + idEspecialidad,
                tokenSocio(ciSocio1), null, cuerpo).estado());
        assertEquals(403, enviar("PATCH", ESPECIALIDADES + idEspecialidad,
                tokenEmpleado(ciFuncionario), null, cuerpo).estado());
    }

    /* ---------- Consultorios ---------- */

    @Test
    void corrigeNombreYUbicacionConservandoTurnos() {
        long turno = sembrarTurno(hoy().plusDays(5), 2);

        Respuesta r = enviar("PATCH", CONSULTORIOS + idConsultorio,
                tokenEmpleado(ciAdmin), null,
                "{\"nombre\":\"Consultorio Renombrado\",\"ubicacion\":\"Piso 9\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("Consultorio Renombrado", r.json().path("nombre").asString());
        assertEquals("Piso 9", r.json().path("ubicacion").asString());
        assertEquals(idConsultorio, jdbc.queryForObject(
                "SELECT id_consultorio FROM turno WHERE id_turno = ?",
                Long.class, turno),
                "El turno conserva su relacion con el consultorio");
    }

    @Test
    void nombreDeConsultorioDuplicadoDevuelve409() {
        jdbc.update("INSERT INTO consultorio (nombre, ubicacion)"
                + " VALUES ('Consultorio 2', 'Piso 2')");

        Respuesta r = enviar("PATCH", CONSULTORIOS + idConsultorio,
                tokenEmpleado(ciAdmin), null, "{\"nombre\":\"CONSULTORIO 2\"}");

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("CONSULTORIO_DUPLICADO", r.codigo());
    }

    @Test
    void consultorioInexistenteDevuelve404() {
        Respuesta r = enviar("PATCH", CONSULTORIOS + 999999,
                tokenEmpleado(ciAdmin), null, "{\"ubicacion\":\"Piso 9\"}");

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("CONSULTORIO_NO_ENCONTRADO", r.codigo());
    }

    @Test
    void correccionDeConsultorioSinCamposDevuelve400() {
        Respuesta r = enviar("PATCH", CONSULTORIOS + idConsultorio,
                tokenEmpleado(ciAdmin), null, "{}");

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
    }

    @Test
    void correccionDeConsultoriosEsExclusivaDelAdministrador() {
        String cuerpo = "{\"ubicacion\":\"Piso 9\"}";

        assertEquals(401, enviar("PATCH", CONSULTORIOS + idConsultorio,
                null, null, cuerpo).estado());
        assertEquals(403, enviar("PATCH", CONSULTORIOS + idConsultorio,
                tokenSocio(ciSocio1), null, cuerpo).estado());
        assertEquals(403, enviar("PATCH", CONSULTORIOS + idConsultorio,
                tokenEmpleado(ciMedico), null, cuerpo).estado());
    }
}
