package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.notificacion.EnvioNotificacionPoller;
import uy.edu.proyecto.backend.notificacion.PushSender;

/**
 * Avisos al socio por correo y por push (RNF-23, RNF-24) contra PostgreSQL real:
 * cada tipo de aviso crea sus envios y los entrega despues del commit, y una
 * falla del proveedor no revierte la operacion. El correo y el push se
 * reemplazan por dobles para no enviar nada de verdad.
 */
class NotificacionesEnvioIT extends BaseIntegracionIT {

    @MockitoBean
    CorreoSender correoSender;

    @MockitoBean
    PushSender pushSender;

    @Autowired
    EnvioNotificacionPoller poller;

    private String correoDe(String ci) {
        return "u" + ci + "@ejemplo.invalid";
    }

    private static String fechaUruguaya(LocalDate fecha) {
        return "%02d/%02d/%d".formatted(fecha.getDayOfMonth(), fecha.getMonthValue(), fecha.getYear());
    }

    private Respuesta agendar(String token, long numeroId) {
        return post("/api/consultas", token, "{\"numeroId\":%d}".formatted(numeroId));
    }

    private long unicaNotificacion(String tipo) {
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE tipo = ?", Integer.class, tipo));
        return jdbc.queryForObject(
                "SELECT id_notificacion FROM notificacion WHERE tipo = ?", Long.class, tipo);
    }

    private List<Map<String, Object>> envios(long notificacionId) {
        return jdbc.queryForList(
                "SELECT canal, estado, intentos, correo_destino, id_dispositivo,"
                        + " ultimo_intento_en IS NOT NULL AS tiene_ultimo_intento"
                        + " FROM envio_notificacion WHERE id_notificacion = ? ORDER BY id_envio",
                notificacionId);
    }

    @Test
    void agendarCreaElAvisoYEntregaElCorreoConElTituloYElCuerpoDeAgenda() {
        LocalDate fecha = hoy().plusDays(3);
        long numero = numeroId(sembrarTurno(fecha, 2), 1);

        Respuesta r = agendar(tokenSocio(ciSocio1), numero);

        assertEquals(201, r.estado(), r.cuerpo());
        long notificacion = unicaNotificacion("AGENDA");
        String cuerpo = "Tu consulta de Medicina General con Mario Medina quedó agendada para el "
                + fechaUruguaya(fecha) + " a las 10:00.";
        assertEquals(cuerpo, jdbc.queryForObject(
                "SELECT contenido FROM notificacion WHERE id_notificacion = ?",
                String.class, notificacion));
        List<Map<String, Object>> filas = envios(notificacion);
        assertEquals(1, filas.size());
        assertEquals("CORREO", filas.getFirst().get("canal"));
        assertEquals("ENVIADO", filas.getFirst().get("estado"));
        assertEquals(1, filas.getFirst().get("intentos"));
        assertEquals(correoDe(ciSocio1), filas.getFirst().get("correo_destino"));
        verify(correoSender).enviar(
                new CorreoMensaje(correoDe(ciSocio1), "Consulta agendada", cuerpo));
    }

    @Test
    void elResultadoDelMedicoCreaElAvisoDeHistoriaSinDatosClinicosYElPushLlevaLaAtencion() {
        jdbc.update("INSERT INTO dispositivo_push (id_socio, token) VALUES (?, ?)",
                idSocio1, "token-a");
        long turno = sembrarTurno(hoy(), 4);
        // Dos atenciones previas de otras consultas, sin aviso, y una consulta sin atencion: asi el
        // id de la atencion de la consulta del socio no coincide con el del aviso ni con el de la consulta.
        sembrarAtencion(sembrarConsulta(idSocio2, numeroId(turno, 2)));
        sembrarAtencion(sembrarConsulta(idSocio3, numeroId(turno, 3)));
        sembrarConsulta(idSocio4, numeroId(turno, 4));
        sembrarConsulta(idSocio1, numeroId(turno, 1));
        jdbc.update("INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (?, ?, ?)",
                idSocio1, idFuncionario, hoy());
        long consulta = jdbc.queryForObject(
                "SELECT id_consulta FROM consulta WHERE id_socio = ?", Long.class, idSocio1);

        Respuesta r = post("/api/medico/consultas/" + consulta + "/resultado",
                tokenEmpleado(ciMedico),
                "{\"resultado\":\"ATENDIDA\",\"afeccion\":\"Hipertension arterial leve\","
                        + "\"tratamiento\":\"Control de dieta\"}");

        assertEquals(200, r.estado(), r.cuerpo());
        long notificacion = unicaNotificacion("HISTORIA_ACTUALIZADA");
        long atencion = jdbc.queryForObject(
                "SELECT id_atencion FROM atencion WHERE id_consulta = ?", Long.class, consulta);
        assertNotEquals(atencion, notificacion,
                "El id de la atencion y el del aviso no pueden coincidir: un JOIN por el id equivocado "
                        + "pasaria por casualidad");
        assertNotEquals(atencion, consulta,
                "El id de la atencion y el de la consulta no pueden coincidir");
        assertEquals("Tu historia clínica fue actualizada.", jdbc.queryForObject(
                "SELECT contenido FROM notificacion WHERE id_notificacion = ?",
                String.class, notificacion));
        List<Map<String, Object>> filas = envios(notificacion);
        assertEquals(2, filas.size());
        assertEquals("CORREO", filas.get(0).get("canal"));
        assertEquals("ENVIADO", filas.get(0).get("estado"));
        assertEquals("PUSH", filas.get(1).get("canal"));
        assertEquals("ENVIADO", filas.get(1).get("estado"));
        verify(correoSender).enviar(new CorreoMensaje(
                correoDe(ciSocio1),
                "Historia clínica actualizada",
                "Tu historia clínica fue actualizada."));
        verify(pushSender).enviar(
                eq("token-a"),
                eq("Historia clínica actualizada"),
                eq("Tu historia clínica fue actualizada."),
                eq(Map.of(
                        "tipo", "HISTORIA_ACTUALIZADA",
                        "notificacionId", String.valueOf(notificacion),
                        "atencionId", String.valueOf(atencion))));
    }

    @Test
    void soloElPushDeHistoriaLlevaElAtencionIdAunqueLaConsultaTengaAtencion() {
        long dispositivo = jdbc.queryForObject(
                "INSERT INTO dispositivo_push (id_socio, token) VALUES (?, ?) RETURNING id_dispositivo",
                Long.class, idSocio1, "token-a");
        long turno = sembrarTurno(hoy().plusDays(3), 3);
        // Una atencion previa de otra consulta y una consulta sin atencion: los ids de la atencion,
        // la consulta y los avisos quedan distintos entre si.
        sembrarAtencion(sembrarConsulta(idSocio2, numeroId(turno, 2)));
        sembrarConsulta(idSocio3, numeroId(turno, 3));
        long consulta = sembrarConsulta(idSocio1, numeroId(turno, 1));
        long atencion = sembrarAtencion(consulta);
        String[][] avisos = {
                {"AGENDA", "Consulta agendada"},
                {"CANCELACION", "Consulta cancelada"},
                {"SUSPENSION", "Turno suspendido"},
                {"HISTORIA_ACTUALIZADA", "Historia clínica actualizada"},
                {"RECORDATORIO", "Recordatorio de consulta"},
        };
        Map<String, Long> notificaciones = new java.util.HashMap<>();
        for (String[] aviso : avisos) {
            long id = jdbc.queryForObject(
                    "INSERT INTO notificacion (id_consulta, tipo, contenido, programada_para)"
                            + " VALUES (?, ?, ?, CASE WHEN ? = 'RECORDATORIO'"
                            + " THEN CURRENT_TIMESTAMP ELSE NULL END) RETURNING id_notificacion",
                    Long.class, consulta, aviso[0], "Cuerpo de " + aviso[0], aviso[0]);
            notificaciones.put(aviso[0], id);
            jdbc.update("INSERT INTO envio_notificacion (id_notificacion, canal, id_dispositivo)"
                    + " VALUES (?, 'PUSH', ?)", id, dispositivo);
        }
        assertNotEquals(atencion, notificaciones.get("HISTORIA_ACTUALIZADA"),
                "El id de la atencion y el del aviso de historia no pueden coincidir");
        assertNotEquals(atencion, consulta,
                "El id de la atencion y el de la consulta no pueden coincidir");

        poller.despacharPendientes();

        for (String[] aviso : avisos) {
            Map<String, String> datos = new java.util.HashMap<>(Map.of(
                    "tipo", aviso[0],
                    "notificacionId", String.valueOf(notificaciones.get(aviso[0]))));
            if (aviso[0].equals("HISTORIA_ACTUALIZADA")) {
                datos.put("atencionId", String.valueOf(atencion));
            }
            verify(pushSender).enviar(
                    eq("token-a"), eq(aviso[1]), eq("Cuerpo de " + aviso[0]), eq(datos));
        }
    }

    @Test
    void laCancelacionDelFuncionarioYaSeEntregaEnVezDeQuedarPendiente() {
        LocalDate fecha = hoy().plusDays(3);
        long numero = numeroId(sembrarTurno(fecha, 1), 1);
        long consulta = sembrarConsulta(idSocio1, numero);

        Respuesta r = post("/api/funcionario/consultas/" + consulta + "/cancelar",
                tokenEmpleado(ciFuncionario), null);

        assertEquals(200, r.estado(), r.cuerpo());
        long notificacion = unicaNotificacion("CANCELACION");
        List<Map<String, Object>> filas = envios(notificacion);
        assertEquals(1, filas.size());
        assertEquals("ENVIADO", filas.getFirst().get("estado"));
        verify(correoSender).enviar(new CorreoMensaje(
                correoDe(ciSocio1),
                "Consulta cancelada",
                "Tu consulta de Medicina General con Mario Medina del " + fechaUruguaya(fecha)
                        + " a las 10:00 fue cancelada a tu solicitud."));
    }

    @Test
    void unaFallaDelCorreoNoRevierteLaCancelacionYQuedaAnotadaEnElEnvio() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(3), 1), 1);
        long consulta = sembrarConsulta(idSocio1, numero);
        doThrow(new UnsupportedOperationException("proveedor caido"))
                .when(correoSender).enviar(any());

        Respuesta r = post("/api/funcionario/consultas/" + consulta + "/cancelar",
                tokenEmpleado(ciFuncionario), null);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals("CANCELADA_SOCIO", estadoConsulta(consulta));
        List<Map<String, Object>> filas = envios(unicaNotificacion("CANCELACION"));
        assertEquals(1, filas.size());
        assertEquals("FALLIDO", filas.getFirst().get("estado"));
        assertEquals(1, filas.getFirst().get("intentos"));
        assertEquals(true, filas.getFirst().get("tiene_ultimo_intento"));
    }

    @Test
    void unaFallaDelPushNoRevierteElAgendadoYElCorreoSeEntregaIgual() {
        jdbc.update("INSERT INTO dispositivo_push (id_socio, token) VALUES (?, ?)",
                idSocio1, "token-a");
        long numero = numeroId(sembrarTurno(hoy().plusDays(3), 1), 1);
        doThrow(new IllegalStateException("firebase no inicializado"))
                .when(pushSender).enviar(any(), any(), any(), any());

        Respuesta r = agendar(tokenSocio(ciSocio1), numero);

        assertEquals(201, r.estado(), r.cuerpo());
        List<Map<String, Object>> filas = envios(unicaNotificacion("AGENDA"));
        assertEquals(2, filas.size());
        assertEquals("CORREO", filas.get(0).get("canal"));
        assertEquals("ENVIADO", filas.get(0).get("estado"));
        assertEquals("PUSH", filas.get(1).get("canal"));
        assertEquals("FALLIDO", filas.get(1).get("estado"));
    }

    @Test
    void conDosDispositivosHabilitadosYUnoNoSeCreanDosFilasDePush() {
        jdbc.update("INSERT INTO dispositivo_push (id_socio, token, habilitado) VALUES (?, ?, ?)",
                idSocio1, "token-a", true);
        jdbc.update("INSERT INTO dispositivo_push (id_socio, token, habilitado) VALUES (?, ?, ?)",
                idSocio1, "token-b", true);
        jdbc.update("INSERT INTO dispositivo_push (id_socio, token, habilitado) VALUES (?, ?, ?)",
                idSocio1, "token-c", false);
        long numero = numeroId(sembrarTurno(hoy().plusDays(3), 1), 1);

        Respuesta r = agendar(tokenSocio(ciSocio1), numero);

        assertEquals(201, r.estado(), r.cuerpo());
        long notificacion = unicaNotificacion("AGENDA");
        List<Map<String, Object>> filas = envios(notificacion);
        assertEquals(3, filas.size());
        assertEquals(List.of("CORREO", "PUSH", "PUSH"),
                filas.stream().map(f -> f.get("canal")).toList());
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM envio_notificacion e"
                        + " JOIN dispositivo_push d ON d.id_dispositivo = e.id_dispositivo"
                        + " WHERE e.id_notificacion = ? AND e.canal = 'PUSH' AND d.habilitado",
                Integer.class, notificacion));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM envio_notificacion e"
                        + " JOIN dispositivo_push d ON d.id_dispositivo = e.id_dispositivo"
                        + " WHERE e.id_notificacion = ? AND d.token = 'token-c'",
                Integer.class, notificacion));
        verify(pushSender).enviar(eq("token-a"), eq("Consulta agendada"), any(),
                eq(Map.of("tipo", "AGENDA", "notificacionId", String.valueOf(notificacion))));
        verify(pushSender).enviar(eq("token-b"), eq("Consulta agendada"), any(),
                eq(Map.of("tipo", "AGENDA", "notificacionId", String.valueOf(notificacion))));
        verify(pushSender, never()).enviar(eq("token-c"), any(), any(), any());
    }

    @Test
    void sinDispositivosSoloSeCreaLaFilaDeCorreo() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(3), 1), 1);

        agendar(tokenSocio(ciSocio1), numero);

        List<Map<String, Object>> filas = envios(unicaNotificacion("AGENDA"));
        assertEquals(1, filas.size());
        assertEquals("CORREO", filas.getFirst().get("canal"));
        verify(pushSender, never()).enviar(any(), any(), any(), any());
    }

    @Test
    void elPollerEntregaLosPendientesDeLosCincoTiposYNoSoloLosDeSuspension() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(3), 1), 1);
        long consulta = sembrarConsulta(idSocio1, numero);
        String[][] avisos = {
                {"AGENDA", "Consulta agendada"},
                {"CANCELACION", "Consulta cancelada"},
                {"SUSPENSION", "Turno suspendido"},
                {"HISTORIA_ACTUALIZADA", "Historia clínica actualizada"},
                {"RECORDATORIO", "Recordatorio de consulta"},
        };
        for (String[] aviso : avisos) {
            long id = jdbc.queryForObject(
                    "INSERT INTO notificacion (id_consulta, tipo, contenido, programada_para)"
                            + " VALUES (?, ?, ?, CASE WHEN ? = 'RECORDATORIO'"
                            + " THEN CURRENT_TIMESTAMP ELSE NULL END) RETURNING id_notificacion",
                    Long.class, consulta, aviso[0], "Cuerpo de " + aviso[0], aviso[0]);
            jdbc.update("INSERT INTO envio_notificacion (id_notificacion, canal, correo_destino)"
                    + " VALUES (?, 'CORREO', ?)", id, correoDe(ciSocio1));
        }
        assertEquals(5, jdbc.queryForObject(
                "SELECT count(*) FROM envio_notificacion WHERE estado = 'PENDIENTE'",
                Integer.class));

        poller.despacharPendientes();

        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM envio_notificacion WHERE estado = 'PENDIENTE'",
                Integer.class));
        assertEquals(5, jdbc.queryForObject(
                "SELECT count(*) FROM envio_notificacion WHERE estado = 'ENVIADO' AND intentos = 1",
                Integer.class));
        for (String[] aviso : avisos) {
            verify(correoSender).enviar(new CorreoMensaje(
                    correoDe(ciSocio1), aviso[1], "Cuerpo de " + aviso[0]));
        }
    }

    @Test
    void unEnvioQueFallaNoFrenaALosQueVienenDetras() {
        long numero = numeroId(sembrarTurno(hoy().plusDays(3), 1), 1);
        long consulta = sembrarConsulta(idSocio1, numero);
        for (int i = 1; i <= 2; i++) {
            long id = jdbc.queryForObject(
                    "INSERT INTO notificacion (id_consulta, tipo, contenido)"
                            + " VALUES (?, 'CANCELACION', ?) RETURNING id_notificacion",
                    Long.class, consulta, "Cuerpo " + i);
            jdbc.update("INSERT INTO envio_notificacion (id_notificacion, canal, correo_destino)"
                    + " VALUES (?, 'CORREO', ?)", id, correoDe(ciSocio1));
        }
        doThrow(new UnsupportedOperationException("proveedor caido"))
                .when(correoSender).enviar(
                        new CorreoMensaje(correoDe(ciSocio1), "Consulta cancelada", "Cuerpo 1"));

        poller.despacharPendientes();

        assertEquals("FALLIDO", jdbc.queryForObject(
                "SELECT e.estado FROM envio_notificacion e"
                        + " JOIN notificacion n ON n.id_notificacion = e.id_notificacion"
                        + " WHERE n.contenido = 'Cuerpo 1'", String.class));
        assertEquals("ENVIADO", jdbc.queryForObject(
                "SELECT e.estado FROM envio_notificacion e"
                        + " JOIN notificacion n ON n.id_notificacion = e.id_notificacion"
                        + " WHERE n.contenido = 'Cuerpo 2'", String.class));
        assertNotNull(jdbc.queryForObject(
                "SELECT ultimo_intento_en FROM envio_notificacion e"
                        + " JOIN notificacion n ON n.id_notificacion = e.id_notificacion"
                        + " WHERE n.contenido = 'Cuerpo 1'", java.time.OffsetDateTime.class));
    }
}
