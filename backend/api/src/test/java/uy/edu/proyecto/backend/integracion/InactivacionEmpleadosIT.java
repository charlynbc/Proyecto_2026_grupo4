package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

/**
 * RF-45: inactivacion y reactivacion de empleados contra PostgreSQL real.
 * La siembra base incluye admin, dos funcionarios, un medico y socios.
 */
class InactivacionEmpleadosIT extends BaseIntegracionIT {

    private static final String INACTIVAR = "/api/usuarios/%d/inactivar";
    private static final String REACTIVAR = "/api/usuarios/%d/reactivar";

    private String admin() {
        return tokenEmpleado(ciAdmin);
    }

    private boolean habilitada(long idCuenta) {
        return Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT habilitada FROM cuenta WHERE id_cuenta = ?",
                Boolean.class, idCuenta));
    }

    private static void esperarSegundo() {
        try {
            Thread.sleep(1200);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /* ---------- Inactivacion ---------- */

    @Test
    void inactivarFuncionarioCortaLoginJwtYRefresh() {
        Respuesta login = login(ciFuncionario, "EMPLEADO");
        assertEquals(200, login.estado(), login.cuerpo());
        String jwtViejo = login.json().path("token").asString();
        String refreshViejo = login.refreshToken();
        assertNotNull(refreshViejo);

        Respuesta r = post(INACTIVAR.formatted(idFuncionario), admin(), null);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("INACTIVA", r.json().path("estado").asString());
        assertEquals(idAdmin, r.json().path("ultimaInactivacionPor").asLong());
        assertTrue(r.json().path("ultimaInactivacionEn").asString().length() > 10);

        assertEquals(false, habilitada(idFuncionario));
        assertEquals(idAdmin, jdbc.queryForObject(
                "SELECT ultimo_inactivador FROM cuenta WHERE id_cuenta = ?",
                Long.class, idFuncionario));
        assertNotNull(jdbc.queryForObject(
                "SELECT ultima_inactivacion_en FROM cuenta WHERE id_cuenta = ?",
                java.sql.Timestamp.class, idFuncionario));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM sesion WHERE id_cuenta = ?"
                        + " AND revocada_en IS NULL",
                Integer.class, idFuncionario),
                "Las sesiones de renovacion quedan revocadas");

        assertEquals(401, get("/api/turnos", jwtViejo).estado(),
                "El JWT emitido antes de la inactivacion deja de autorizar");
        assertEquals(401, login(ciFuncionario, "EMPLEADO").estado(),
                "La cuenta inactivada no puede iniciar sesion");
        assertEquals(401, enviar("POST", "/api/auth/refresh", null,
                refreshViejo, null).estado(),
                "El refresh token de la cuenta inactivada se rechaza");
    }

    @Test
    void inactivarMedicoSinAgendaFunciona() {
        Respuesta r = post(INACTIVAR.formatted(idMedico), admin(), null);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("INACTIVA", r.json().path("estado").asString());
        assertEquals(false, habilitada(idMedico));
    }

    @Test
    void medicoConTurnoActivoFuturoNoSeInactiva() {
        sembrarTurno(hoy().plusDays(7), 2);

        Respuesta r = post(INACTIVAR.formatted(idMedico), admin(), null);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("MEDICO_CON_TURNOS_ACTIVOS", r.codigo());
        assertEquals(true, habilitada(idMedico), "La cuenta sigue habilitada");
    }

    @Test
    void medicoConTurnoActivoDeHoyNoSeInactiva() {
        sembrarTurno(hoy(), 2);

        Respuesta r = post(INACTIVAR.formatted(idMedico), admin(), null);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("MEDICO_CON_TURNOS_ACTIVOS", r.codigo());
    }

    @Test
    void medicoConTurnoDeDiaTerminadoSeInactiva() {
        sembrarTurno(hoy().minusDays(7), 2);

        Respuesta r = post(INACTIVAR.formatted(idMedico), admin(), null);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(false, habilitada(idMedico));
    }

    @Test
    void medicoConConsultaAgendadaFuturaNoSeInactiva() {
        // Turno suspendido (no cuenta como fecha activa) con una consulta
        // agendada futura sembrada directamente: la guarda la detecta igual.
        long turno = sembrarTurno(hoy().plusDays(5), 1);
        jdbc.update("UPDATE turno SET estado = 'SUSPENDIDO' WHERE id_turno = ?",
                turno);
        sembrarConsulta(idSocio1, numeroId(turno, 1));

        Respuesta r = post(INACTIVAR.formatted(idMedico), admin(), null);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("MEDICO_CON_CONSULTAS_AGENDADAS", r.codigo());
        assertEquals(true, habilitada(idMedico));
    }

    @Test
    void medicoTrasSuspenderSusFechasSeInactiva() {
        String funcionario = tokenEmpleado(ciFuncionario);
        LocalDate fecha = hoy().plusDays(7);
        long turno = crearTurnoPorApi(funcionario, fecha, 2);
        assertEquals(201, post("/api/consultas", tokenSocio(ciSocio1),
                "{\"numeroId\":" + numeroId(turno, 1) + "}").estado());

        // RF-14: se suspenden las fechas y sus consultas se cancelan.
        Respuesta suspension = post("/api/turnos/suspensiones", funcionario, """
                {"filtro":{"medicoId":%d,"especialidadId":%d,"fechaDesde":"%s","fechaHasta":"%s"},
                 "ids":[%d],"observacion":"Baja administrativa","cantidadConfirmada":1}
                """.formatted(idMedico, idEspecialidad,
                fecha.minusDays(1), fecha.plusDays(1), turno));
        assertEquals(200, suspension.estado(), suspension.cuerpo());

        Respuesta r = post(INACTIVAR.formatted(idMedico), admin(), null);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(false, habilitada(idMedico));
        assertEquals("CANCELADA_INSTITUCION", jdbc.queryForObject(
                "SELECT estado FROM consulta", String.class));
    }

    @Test
    void inactivarCuentaYaInactivaDevuelve409() {
        assertEquals(200, post(INACTIVAR.formatted(idFuncionario), admin(), null)
                .estado());

        Respuesta r = post(INACTIVAR.formatted(idFuncionario), admin(), null);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("CUENTA_YA_INACTIVA", r.codigo());
    }

    @Test
    void inactivarSocioSeRechazaYSuCuentaNoSeToca() {
        Respuesta r = post(INACTIVAR.formatted(idSocio1), admin(), null);

        assertEquals(400, r.estado(), r.cuerpo());
        assertEquals("VALIDACION", r.codigo());
        assertEquals(true, habilitada(idSocio1));
    }

    @Test
    void inactivarCuentaInexistenteDevuelve404() {
        Respuesta r = post(INACTIVAR.formatted(999999), admin(), null);

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals("USUARIO_NO_ENCONTRADO", r.codigo());
    }

    @Test
    void inactivarEmpleadoNoAfectaLaCuentaDeSocioDeLaMismaPersona() {
        // La persona de ciSocio1 tambien tiene una cuenta de medico.
        Respuesta alta = post("/api/usuarios", admin(), """
                {"ci":"%s","nombre":"Sofia","apellido":"Socia",
                 "fechaNacimiento":"1985-05-05","correo":"sofia.med@ejemplo.invalid",
                 "telefono1":"099111222","rol":"MEDICO","especialidadIds":[%d]}
                """.formatted(ciSocio1, idEspecialidad));
        assertEquals(201, alta.estado(), alta.cuerpo());
        long idMedicoSocio = alta.json().path("id").asLong();

        Respuesta r = post(INACTIVAR.formatted(idMedicoSocio), admin(), null);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(false, habilitada(idMedicoSocio));
        assertEquals(true, habilitada(idSocio1),
                "La cuenta de Socio de la misma persona no se modifica");
        assertEquals(200, login(ciSocio1, "SOCIO").estado(),
                "El socio sigue pudiendo iniciar sesion");
    }

    /* ---------- Reactivacion ---------- */

    @Test
    void reactivarDevuelveLaCuentaAlServicioConAuditoria() {
        post(INACTIVAR.formatted(idFuncionario), admin(), null);
        esperarSegundo();

        Respuesta r = post(REACTIVAR.formatted(idFuncionario), admin(), null);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("ACTIVA", r.json().path("estado").asString());
        assertEquals(idAdmin, r.json().path("ultimaReactivacionPor").asLong());
        assertTrue(r.json().path("ultimaReactivacionEn").asString().length() > 10);
        assertEquals(true, habilitada(idFuncionario));
        assertEquals(200, login(ciFuncionario, "EMPLEADO").estado(),
                "La cuenta reactivada puede iniciar sesion de nuevo");
    }

    @Test
    void reactivacionNoReviveElJwtAnteriorALaInactivacion() {
        String jwtViejo = tokenEmpleado(ciFuncionario);
        post(INACTIVAR.formatted(idFuncionario), admin(), null);
        esperarSegundo();
        assertEquals(200, post(REACTIVAR.formatted(idFuncionario), admin(), null)
                .estado());

        assertEquals(401, get("/api/turnos", jwtViejo).estado(),
                "El JWT anterior a la inactivacion no revive al reactivar");
        assertEquals(200, get("/api/turnos", tokenEmpleado(ciFuncionario)).estado(),
                "Un login nuevo si funciona");
    }

    @Test
    void reactivarConOtraCuentaEmpleadoHabilitadaDevuelve409() {
        assertEquals(200, post(INACTIVAR.formatted(idMedico), admin(), null)
                .estado());

        // Con la cuenta de medico inactiva, el alta de otra cuenta de
        // empleado para la misma CI es valida (RF-31).
        Respuesta alta = post("/api/usuarios", admin(), """
                {"ci":"%s","nombre":"Mario","apellido":"Medina",
                 "fechaNacimiento":"1985-05-05","correo":"mario.f@ejemplo.invalid",
                 "telefono1":"099333444","rol":"FUNCIONARIO"}
                """.formatted(ciMedico));
        assertEquals(201, alta.estado(), alta.cuerpo());

        Respuesta r = post(REACTIVAR.formatted(idMedico), admin(), null);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("EMPLEADO_DUPLICADO", r.codigo());
        assertEquals(false, habilitada(idMedico),
                "La cuenta inactivada no se rehabilita");
    }

    @Test
    void reactivarConOtraCuentaPendienteDePrimerIngresoDevuelve409() {
        String ciPendiente = ci(1000006);
        Respuesta primera = post("/api/usuarios", admin(), """
                {"ci":"%s","nombre":"Pablo","apellido":"Perez",
                 "fechaNacimiento":"1990-01-01","correo":"pablo1@ejemplo.invalid",
                 "telefono1":"099111222","rol":"FUNCIONARIO"}
                """.formatted(ciPendiente));
        assertEquals(201, primera.estado(), primera.cuerpo());
        long idPrimera = primera.json().path("id").asLong();

        // Cuenta pendiente de primer ingreso: tambien se puede inactivar.
        assertEquals(200, post(INACTIVAR.formatted(idPrimera), admin(), null)
                .estado());

        Respuesta segunda = post("/api/usuarios", admin(), """
                {"ci":"%s","nombre":"Pablo","apellido":"Perez",
                 "fechaNacimiento":"1990-01-01","correo":"pablo2@ejemplo.invalid",
                 "telefono1":"099111222","rol":"FUNCIONARIO"}
                """.formatted(ciPendiente));
        assertEquals(201, segunda.estado(), segunda.cuerpo());

        Respuesta r = post(REACTIVAR.formatted(idPrimera), admin(), null);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("EMPLEADO_DUPLICADO", r.codigo());
    }

    @Test
    void reactivarCuentaYaActivaDevuelve409() {
        Respuesta r = post(REACTIVAR.formatted(idFuncionario), admin(), null);

        assertEquals(409, r.estado(), r.cuerpo());
        assertEquals("CUENTA_YA_ACTIVA", r.codigo());
    }

    @Test
    void reactivarNoRehabilitaLasFechasSuspendidas() {
        String funcionario = tokenEmpleado(ciFuncionario);
        LocalDate fecha = hoy().plusDays(7);
        long turno = crearTurnoPorApi(funcionario, fecha, 1);
        assertEquals(200, post("/api/turnos/suspensiones", funcionario, """
                {"filtro":{"medicoId":%d,"especialidadId":%d,"fechaDesde":"%s","fechaHasta":"%s"},
                 "ids":[%d],"observacion":"Baja","cantidadConfirmada":0}
                """.formatted(idMedico, idEspecialidad,
                fecha.minusDays(1), fecha.plusDays(1), turno)).estado());

        assertEquals(200, post(INACTIVAR.formatted(idMedico), admin(), null)
                .estado());
        assertEquals(200, post(REACTIVAR.formatted(idMedico), admin(), null)
                .estado());

        assertEquals("SUSPENDIDO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?",
                String.class, turno),
                "La fecha suspendida no se rehabilita al reactivar (RF-15)");
    }

    @Test
    void historialDelEmpleadoSeConservaTrasInactivarYReactivar() {
        long turno = sembrarTurno(hoy().minusDays(7), 1);
        long consulta = sembrarConsulta(idSocio1, numeroId(turno, 1));
        jdbc.update("""
                UPDATE consulta SET estado = 'ATENDIDA', resultado_registrado_por = ?,
                       fecha_resultado = CURRENT_TIMESTAMP WHERE id_consulta = ?
                """, idMedico, consulta);
        jdbc.update("""
                INSERT INTO atencion (id_consulta, id_medico, afeccion)
                VALUES (?, ?, 'Afeccion historica')
                """, consulta, idMedico);

        assertEquals(200, post(INACTIVAR.formatted(idMedico), admin(), null)
                .estado());
        assertEquals(200, post(REACTIVAR.formatted(idMedico), admin(), null)
                .estado());

        assertEquals("ATENDIDA", estadoConsulta(consulta));
        assertEquals("Afeccion historica", jdbc.queryForObject(
                "SELECT afeccion FROM atencion WHERE id_consulta = ?",
                String.class, consulta));
        assertEquals(1, contar("atencion"));
    }

    @Test
    void soloAdministradorInactivaYReactiva() {
        assertEquals(401, post(INACTIVAR.formatted(idFuncionario), null, null)
                .estado());
        assertEquals(401, post(REACTIVAR.formatted(idFuncionario), null, null)
                .estado());
        assertEquals(403, post(INACTIVAR.formatted(idFuncionario),
                tokenSocio(ciSocio1), null).estado());
        assertEquals(403, post(REACTIVAR.formatted(idFuncionario),
                tokenSocio(ciSocio1), null).estado());
        assertEquals(403, post(INACTIVAR.formatted(idFuncionario2),
                tokenEmpleado(ciFuncionario), null).estado());
        assertEquals(403, post(REACTIVAR.formatted(idMedico),
                tokenEmpleado(ciMedico), null).estado());

        assertEquals(true, habilitada(idFuncionario));
        assertEquals(true, habilitada(idFuncionario2));
        assertEquals(true, habilitada(idMedico));
        assertNull(jdbc.queryForObject(
                "SELECT ultimo_inactivador FROM cuenta WHERE id_cuenta = ?",
                Long.class, idFuncionario),
                "Los rechazos no registran auditoria ni modifican la base");
    }
}
