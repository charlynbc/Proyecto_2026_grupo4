package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;

/** RF-20 contra PostgreSQL real: modificacion del consultorio de un turno semanal. */
class ModificacionTurnoSemanalIT extends BaseIntegracionIT {

    private long consultorioNuevo() {
        return jdbc.queryForObject(
                "INSERT INTO consultorio (nombre, ubicacion)"
                        + " VALUES ('Consultorio 9', 'Anexo') RETURNING id_consultorio",
                Long.class);
    }

    private long idPatronDe(long turno) {
        return jdbc.queryForObject(
                "SELECT id_turno_semanal FROM turno WHERE id_turno = ?",
                Long.class, turno);
    }

    private long consultorioDelTurno(long turno) {
        return jdbc.queryForObject(
                "SELECT id_consultorio FROM turno WHERE id_turno = ?",
                Long.class, turno);
    }

    private Respuesta modificar(String token, long patron, long consultorio) {
        return enviar("PATCH", "/api/turnos-semanales/" + patron, token, null,
                "{\"consultorioId\":" + consultorio + "}");
    }

    @Test
    void modificacionValidaActualizaConfiguracionYFechasVigentes() {
        String funcionario = tokenEmpleado(ciFuncionario);
        LocalDate fecha = hoy().plusDays(7);
        long turno = crearTurnoPorApi(funcionario, fecha, 2);
        long patron = idPatronDe(turno);
        long nuevo = consultorioNuevo();

        Respuesta r = modificar(funcionario, patron, nuevo);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(nuevo, r.json().path("consultorio").path("id").asLong());
        assertEquals("Consultorio 9",
                r.json().path("consultorio").path("nombre").asString());
        assertEquals(nuevo, consultorioDelTurno(turno));
        assertEquals(nuevo, jdbc.queryForObject(
                "SELECT id_consultorio FROM turno_semanal WHERE id_turno_semanal = ?",
                Long.class, patron));
    }

    @Test
    void turnoOConsultorioInexistenteDevuelve404() {
        String funcionario = tokenEmpleado(ciFuncionario);
        long nuevo = consultorioNuevo();

        assertEquals(404, modificar(funcionario, 999999, nuevo).estado());

        LocalDate fecha = hoy().plusDays(7);
        long patron = idPatronDe(crearTurnoPorApi(funcionario, fecha, 1));
        assertEquals(404, modificar(funcionario, patron, 999999).estado());
    }

    @Test
    void conConsultaAgendadaVigenteSeRechazaYNoCambiaNada() {
        String funcionario = tokenEmpleado(ciFuncionario);
        LocalDate fecha = hoy().plusDays(7);
        long turno = crearTurnoPorApi(funcionario, fecha, 2);
        long patron = idPatronDe(turno);
        sembrarConsulta(idSocio1, numeroId(turno, 1));
        long nuevo = consultorioNuevo();

        Respuesta r = modificar(funcionario, patron, nuevo);

        assertEquals(409, r.estado());
        assertEquals("TURNO_NO_MODIFICABLE", r.codigo());
        assertEquals(idConsultorio, consultorioDelTurno(turno));
        assertEquals("AGENDADA", estadoConsulta(
                jdbc.queryForObject(
                        "SELECT id_consulta FROM consulta WHERE id_numero = ?",
                        Long.class, numeroId(turno, 1))));
    }

    @Test
    void consultaAgendadaDeFechaPasadaNoBloqueaNiSeAltera() {
        String funcionario = tokenEmpleado(ciFuncionario);
        // Patron que cubre una fecha pasada y una futura (mismo dia de semana).
        LocalDate pasada = hoy().minusDays(7);
        LocalDate futura = hoy();
        long patron = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, idMedico, idEspecialidad, idConsultorio, idFuncionario,
                diaSemana(pasada), pasada, futura);
        long turnoPasado = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha)"
                        + " VALUES (?, ?, ?) RETURNING id_turno",
                Long.class, patron, idConsultorio, pasada);
        long turnoFuturo = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha)"
                        + " VALUES (?, ?, ?) RETURNING id_turno",
                Long.class, patron, idConsultorio, futura);
        for (long t : new long[]{turnoPasado, turnoFuturo}) {
            // INSERT ... ON CONFLICT DO NOTHING RETURNING no devuelve fila si ya
            // existe, y queryForObject lanzaria EmptyResultDataAccessException:
            // se inserta una sola vez y luego se consulta el id.
            jdbc.update("INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, 1, TIME '09:00', TIME '09:20')"
                            + " ON CONFLICT DO NOTHING",
                    patron);
            long ns = jdbc.queryForObject(
                    "SELECT id_numero_semanal FROM numero_semanal"
                            + " WHERE id_turno_semanal = ? AND numero = 1",
                    Long.class, patron);
            jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero,"
                            + " hora_inicio, hora_fin) VALUES (?, ?, 1, TIME '09:00', TIME '09:20')",
                    t, ns);
        }
        long consultaPasada = sembrarConsulta(idSocio1, numeroId(turnoPasado, 1));
        long nuevo = consultorioNuevo();

        Respuesta r = modificar(funcionario, patron, nuevo);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(idConsultorio, consultorioDelTurno(turnoPasado),
                "la fecha pasada conserva su consultorio");
        assertEquals(nuevo, consultorioDelTurno(turnoFuturo));
        assertEquals("AGENDADA", estadoConsulta(consultaPasada));
    }

    @Test
    void fechaSuspendidaCambiaDeConsultorioPeroSigueSuspendida() {
        String funcionario = tokenEmpleado(ciFuncionario);
        LocalDate fecha = hoy().plusDays(7);
        long turno = crearTurnoPorApi(funcionario, fecha, 1);
        long patron = idPatronDe(turno);
        jdbc.update("UPDATE turno SET estado = 'SUSPENDIDO' WHERE id_turno = ?",
                turno);
        long nuevo = consultorioNuevo();

        // Sin fechas activas vigentes no hay nada que modificar: 409.
        Respuesta sinActivas = modificar(funcionario, patron, nuevo);
        assertEquals(409, sinActivas.estado());
        assertEquals("TURNO_NO_MODIFICABLE", sinActivas.codigo());

        // Con otra fecha activa, la suspendida se mueve conservando su estado.
        LocalDate otraFecha = hoy().plusDays(14);
        jdbc.update("INSERT INTO turno (id_turno_semanal, id_consultorio, fecha)"
                        + " VALUES (?, ?, ?)",
                patron, idConsultorio, otraFecha);
        long ns = jdbc.queryForObject(
                "SELECT id_numero_semanal FROM numero_semanal"
                        + " WHERE id_turno_semanal = ? AND numero = 1",
                Long.class, patron);
        long turnoOtraFecha = jdbc.queryForObject(
                "SELECT id_turno FROM turno WHERE id_turno_semanal = ? AND fecha = ?",
                Long.class, patron, otraFecha);
        jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero,"
                        + " hora_inicio, hora_fin)"
                        + " VALUES (?, ?, 1, TIME '09:00', TIME '09:20')",
                turnoOtraFecha, ns);

        Respuesta r = modificar(funcionario, patron, nuevo);
        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(nuevo, consultorioDelTurno(turno));
        assertEquals("SUSPENDIDO", jdbc.queryForObject(
                "SELECT estado FROM turno WHERE id_turno = ?",
                String.class, turno));
    }

    @Test
    void solapamientoConTurnoDelConsultorioDestinoDevuelve409() {
        String funcionario = tokenEmpleado(ciFuncionario);
        LocalDate fecha = hoy().plusDays(7);
        // Turno A: medico sembrado, consultorio sembrado, 09:00-09:20.
        long turnoA = crearTurnoPorApi(funcionario, fecha, 1);
        long patronA = idPatronDe(turnoA);
        long consultorioB = consultorioNuevo();

        // Otro medico con turno activo en el consultorio destino, 09:10-09:30.
        String ciMedico2 = ci(1000009);
        jdbc.update("INSERT INTO persona VALUES (?, 'Marta', 'Medica', DATE '1980-01-01')",
                ciMedico2);
        long idMedico2 = jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion,"
                        + " contrasena_hash, primer_ingreso_completado)"
                        + " VALUES (?, 'MEDICO', ?, '099111222', 'Calle 1', ?, TRUE)"
                        + " RETURNING id_cuenta",
                Long.class, ciMedico2, "m" + ciMedico2 + "@ejemplo.invalid",
                jdbc.queryForObject(
                        "SELECT contrasena_hash FROM cuenta WHERE id_cuenta = ?",
                        String.class, idMedico));
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)",
                idMedico2, idEspecialidad);
        long patronB = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, idMedico2, idEspecialidad, consultorioB, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turnoB = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha)"
                        + " VALUES (?, ?, ?) RETURNING id_turno",
                Long.class, patronB, consultorioB, fecha);
        long nsB = jdbc.queryForObject(
                "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                        + " VALUES (?, 1, TIME '09:10', TIME '09:30') RETURNING id_numero_semanal",
                Long.class, patronB);
        jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero,"
                        + " hora_inicio, hora_fin)"
                        + " VALUES (?, ?, 1, TIME '09:10', TIME '09:30')",
                turnoB, nsB);

        Respuesta r = modificar(funcionario, patronA, consultorioB);

        assertEquals(409, r.estado());
        assertEquals("SOLAPAMIENTO_TURNO", r.codigo());
        assertEquals(idConsultorio, consultorioDelTurno(turnoA));
    }

    @Test
    void sinAutenticacion401YRolesAjenos403() {
        LocalDate fecha = hoy().plusDays(7);
        String funcionario = tokenEmpleado(ciFuncionario);
        long patron = idPatronDe(crearTurnoPorApi(funcionario, fecha, 1));
        long nuevo = consultorioNuevo();

        assertEquals(401, modificar(null, patron, nuevo).estado());
        assertEquals(403, modificar(tokenSocio(ciSocio1), patron, nuevo).estado());
        assertEquals(403, modificar(tokenEmpleado(ciMedico), patron, nuevo).estado());
    }

    @Test
    void dosModificacionesConcurrentesSeSerializan() throws Exception {
        String funcionario = tokenEmpleado(ciFuncionario);
        LocalDate fecha = hoy().plusDays(7);
        long patron = idPatronDe(crearTurnoPorApi(funcionario, fecha, 1));
        long consultorioX = consultorioNuevo();
        long consultorioY = jdbc.queryForObject(
                "INSERT INTO consultorio (nombre, ubicacion)"
                        + " VALUES ('Consultorio 10', 'Anexo 2') RETURNING id_consultorio",
                Long.class);

        CyclicBarrier barrera = new CyclicBarrier(2);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<Respuesta> a = pool.submit(() -> {
                barrera.await(10, TimeUnit.SECONDS);
                return modificar(funcionario, patron, consultorioX);
            });
            Future<Respuesta> b = pool.submit(() -> {
                barrera.await(10, TimeUnit.SECONDS);
                return modificar(funcionario, patron, consultorioY);
            });

            List<Respuesta> respuestas = List.of(a.get(), b.get());
            for (Respuesta r : respuestas) {
                assertEquals(200, r.estado(), r.cuerpo());
            }
            long finalConsultorio = jdbc.queryForObject(
                    "SELECT id_consultorio FROM turno_semanal WHERE id_turno_semanal = ?",
                    Long.class, patron);
            assertTrue(finalConsultorio == consultorioX
                            || finalConsultorio == consultorioY,
                    "el estado final es uno de los dos pedidos, nunca una mezcla");
        } finally {
            pool.shutdownNow();
        }
    }
}
