package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class TurnoFechasRepository {

    private final JdbcTemplate jdbcTemplate;

    public TurnoFechasRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<TurnoFecha> buscarTurnos(List<Long> ids) {
        return jdbcTemplate.query(
                """
                SELECT t.id_turno, t.id_turno_semanal, t.fecha, t.estado,
                       ts.id_medico, ts.id_especialidad, t.id_consultorio,
                       MIN(n.hora_inicio) AS hora_inicio,
                       MAX(n.hora_fin) AS hora_fin,
                       COUNT(consulta.id_consulta)
                           FILTER (WHERE consulta.estado = 'AGENDADA')
                           AS consultas_agendadas
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                LEFT JOIN public.numero n ON n.id_turno = t.id_turno
                LEFT JOIN public.consulta
                  ON consulta.id_numero = n.id_numero
                WHERE t.id_turno IN (%s)
                GROUP BY t.id_turno, t.id_turno_semanal, t.fecha, t.estado,
                         ts.id_medico, ts.id_especialidad, t.id_consultorio
                ORDER BY t.fecha, t.id_turno
                """.formatted(placeholders(ids.size())),
                (rs, rowNum) -> new TurnoFecha(
                        rs.getLong("id_turno"),
                        rs.getLong("id_turno_semanal"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getString("estado"),
                        rs.getLong("id_medico"),
                        rs.getLong("id_especialidad"),
                        rs.getLong("id_consultorio"),
                        hora(rs.getObject("hora_inicio", LocalTime.class)),
                        hora(rs.getObject("hora_fin", LocalTime.class)),
                        rs.getInt("consultas_agendadas")
                ),
                ids.toArray()
        );
    }

    public List<Long> bloquearTurnos(List<Long> ids) {
        return jdbcTemplate.query(
                """
                SELECT id_turno
                FROM public.turno
                WHERE id_turno IN (%s)
                ORDER BY id_turno
                FOR UPDATE
                """.formatted(placeholders(ids.size())),
                (rs, rowNum) -> rs.getLong("id_turno"),
                ids.toArray()
        );
    }

    public void bloquearNumerosDeTurnos(List<Long> ids) {
        jdbcTemplate.query(
                """
                SELECT numero.id_numero
                FROM public.numero numero
                WHERE numero.id_turno IN (%s)
                ORDER BY numero.id_turno, numero.id_numero
                FOR UPDATE
                """.formatted(placeholders(ids.size())),
                (rs, rowNum) -> rs.getLong("id_numero"),
                ids.toArray()
        );
    }

    public List<ConsultaParaCancelar> bloquearConsultasAgendadas(
            List<Long> ids
    ) {
        return jdbcTemplate.query(
                """
                SELECT consulta.id_consulta, consulta.id_socio,
                       consulta.id_numero, t.id_turno, t.fecha,
                       numero.hora_inicio, numero.hora_fin, numero.numero,
                       cuenta.correo
                FROM public.consulta consulta
                JOIN public.numero numero
                  ON numero.id_numero = consulta.id_numero
                JOIN public.turno t ON t.id_turno = numero.id_turno
                JOIN public.cuenta cuenta
                  ON cuenta.id_cuenta = consulta.id_socio
                WHERE t.id_turno IN (%s)
                  AND consulta.estado = 'AGENDADA'
                ORDER BY consulta.id_consulta
                FOR UPDATE OF consulta
                """.formatted(placeholders(ids.size())),
                (rs, rowNum) -> new ConsultaParaCancelar(
                        rs.getLong("id_consulta"),
                        rs.getLong("id_socio"),
                        rs.getObject("id_numero", Long.class),
                        rs.getLong("id_turno"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getObject("hora_inicio", LocalTime.class),
                        rs.getObject("hora_fin", LocalTime.class),
                        rs.getObject("numero", Integer.class) == null
                                ? 0 : rs.getInt("numero"),
                        rs.getString("correo")
                ),
                ids.toArray()
        );
    }

    public void bloquearMedicos(List<Long> ids) {
        if (ids.isEmpty()) {
            return;
        }
        jdbcTemplate.query(
                """
                SELECT id_cuenta
                FROM public.cuenta
                WHERE id_cuenta IN (%s) AND rol = 'MEDICO'
                ORDER BY id_cuenta
                FOR UPDATE
                """.formatted(placeholders(ids.size())),
                (rs, rowNum) -> rs.getLong("id_cuenta"),
                ids.toArray()
        );
    }

    public void bloquearConsultorios(List<Long> ids) {
        if (ids.isEmpty()) {
            return;
        }
        jdbcTemplate.query(
                """
                SELECT id_consultorio
                FROM public.consultorio
                WHERE id_consultorio IN (%s)
                ORDER BY id_consultorio
                FOR UPDATE
                """.formatted(placeholders(ids.size())),
                (rs, rowNum) -> rs.getLong("id_consultorio"),
                ids.toArray()
        );
    }

    public List<RecursoTurno> buscarRecursos(List<Long> ids) {
        return jdbcTemplate.query(
                """
                SELECT t.id_turno, t.id_turno_semanal, t.fecha, t.estado,
                       ts.id_medico,
                       (cuenta.habilitada AND cuenta.rol = 'MEDICO')
                           AS medico_habilitado,
                       ts.id_especialidad, t.id_consultorio,
                       numero.id_numero, numero.numero,
                       numero.hora_inicio, numero.hora_fin
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.cuenta cuenta
                  ON cuenta.id_cuenta = ts.id_medico
                LEFT JOIN public.numero numero ON numero.id_turno = t.id_turno
                WHERE t.id_turno IN (%s)
                ORDER BY t.id_turno, numero.id_numero
                """.formatted(placeholders(ids.size())),
                (rs, rowNum) -> new RecursoTurno(
                        rs.getLong("id_turno"),
                        rs.getLong("id_turno_semanal"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getString("estado"),
                        rs.getLong("id_medico"),
                        rs.getBoolean("medico_habilitado"),
                        rs.getLong("id_especialidad"),
                        rs.getLong("id_consultorio"),
                        rs.getObject("id_numero", Long.class),
                        rs.getInt("numero"),
                        rs.getObject("hora_inicio", LocalTime.class),
                        rs.getObject("hora_fin", LocalTime.class)
                ),
                ids.toArray()
        );
    }

    public List<NumeroExistente> buscarNumerosActivosEnFechas(
            List<Long> idsSeleccionados,
            List<Long> medicos,
            List<Long> consultorios,
            LocalDate desde,
            LocalDate hasta
    ) {
        return jdbcTemplate.query(
                """
                SELECT t.id_turno, t.fecha, ts.id_medico, t.id_consultorio,
                       numero.numero, numero.hora_inicio, numero.hora_fin
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.numero numero ON numero.id_turno = t.id_turno
                WHERE t.estado = 'ACTIVO'
                  AND t.fecha BETWEEN ? AND ?
                  AND t.id_turno NOT IN (%s)
                  AND (ts.id_medico IN (%s)
                       OR t.id_consultorio IN (%s))
                ORDER BY t.fecha, ts.id_medico, t.id_consultorio,
                         numero.hora_inicio, numero.id_numero
                """.formatted(
                        placeholders(idsSeleccionados.size()),
                        placeholders(medicos.size()),
                        placeholders(consultorios.size())
                ),
                (rs, rowNum) -> new NumeroExistente(
                        rs.getLong("id_turno"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getLong("id_medico"),
                        rs.getLong("id_consultorio"),
                        rs.getInt("numero"),
                        rs.getObject("hora_inicio", LocalTime.class),
                        rs.getObject("hora_fin", LocalTime.class)
                ),
                parametros(desde, hasta, idsSeleccionados, medicos, consultorios)
                        .toArray()
        );
    }

    public Long crearEvento(
            Long turnoId,
            Long responsableId,
            String tipo,
            String observacion
    ) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.turno_evento
                    (id_turno, id_responsable, tipo, observacion)
                VALUES (?, ?, ?, ?)
                RETURNING id_evento
                """,
                Long.class,
                turnoId,
                responsableId,
                tipo,
                observacion
        );
    }

    public void actualizarEstadoTurno(Long turnoId, String estado) {
        jdbcTemplate.update(
                "UPDATE public.turno SET estado = ? WHERE id_turno = ?",
                estado,
                turnoId
        );
    }

    public int cancelarConsulta(
            Long consultaId,
            Long responsableId,
            OffsetDateTime canceladaEn,
            String observacion,
            Long eventoId
    ) {
        return jdbcTemplate.update(
                """
                UPDATE public.consulta
                SET estado = 'CANCELADA_INSTITUCION',
                    cancelada_por = ?,
                    cancelada_en = ?,
                    motivo_cancelacion = ?,
                    id_evento_suspension = ?
                WHERE id_consulta = ? AND estado = 'AGENDADA'
                """,
                responsableId,
                canceladaEn,
                observacion,
                eventoId,
                consultaId
        );
    }

    public long crearNotificacionSuspension(Long consultaId, String contenido) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.notificacion (id_consulta, tipo, contenido)
                VALUES (?, 'SUSPENSION', ?)
                RETURNING id_notificacion
                """,
                Long.class,
                consultaId,
                contenido
        );
    }

    public List<Long> registrarEnviosNotificacion(
            Long notificacionId,
            Long socioId,
            String correo
    ) {
        List<Long> envios = new ArrayList<>();
        if (correo != null && !correo.isBlank()) {
            Long id = jdbcTemplate.queryForObject(
                    """
                    INSERT INTO public.envio_notificacion
                        (id_notificacion, canal, correo_destino)
                    VALUES (?, 'CORREO', ?)
                    RETURNING id_envio
                    """,
                    Long.class,
                    notificacionId,
                    correo
            );
            envios.add(id);
        }
        List<Long> dispositivos = jdbcTemplate.query(
                """
                SELECT id_dispositivo
                FROM public.dispositivo_push
                WHERE id_socio = ? AND habilitado
                ORDER BY id_dispositivo
                """,
                (rs, rowNum) -> rs.getLong("id_dispositivo"),
                socioId
        );
        for (Long dispositivoId : dispositivos) {
            Long id = jdbcTemplate.queryForObject(
                    """
                    INSERT INTO public.envio_notificacion
                        (id_notificacion, canal, id_dispositivo)
                    VALUES (?, 'PUSH', ?)
                    RETURNING id_envio
                    """,
                    Long.class,
                    notificacionId,
                    dispositivoId
            );
            envios.add(id);
        }
        return envios;
    }

    public Optional<EnvioNotificacion> buscarEnvio(Long envioId) {
        return jdbcTemplate.query(
                        """
                        SELECT envio.id_envio, envio.id_notificacion,
                               envio.canal, envio.correo_destino,
                               dispositivo.token,
                               notificacion.contenido,
                               t.fecha, n.hora_inicio, n.hora_fin,
                               e.nombre AS especialidad_nombre,
                               p.nombre AS socio_nombre
                        FROM public.envio_notificacion envio
                        JOIN public.notificacion notificacion
                          ON notificacion.id_notificacion = envio.id_notificacion
                        JOIN public.consulta consulta
                          ON consulta.id_consulta = notificacion.id_consulta
                        JOIN public.cuenta socio
                          ON socio.id_cuenta = consulta.id_socio
                        JOIN public.persona p ON p.ci = socio.ci
                        JOIN public.numero n ON n.id_numero = consulta.id_numero
                        JOIN public.turno t ON t.id_turno = n.id_turno
                        JOIN public.turno_semanal ts
                          ON ts.id_turno_semanal = t.id_turno_semanal
                        JOIN public.especialidad e
                          ON e.id_especialidad = ts.id_especialidad
                        LEFT JOIN public.dispositivo_push dispositivo
                          ON dispositivo.id_dispositivo = envio.id_dispositivo
                        WHERE envio.id_envio = ?
                          AND notificacion.tipo = 'SUSPENSION'
                          AND envio.estado = 'PENDIENTE'
                        FOR UPDATE OF envio
                        """,
                        (rs, rowNum) -> new EnvioNotificacion(
                                rs.getLong("id_envio"),
                                rs.getLong("id_notificacion"),
                                rs.getString("canal"),
                                rs.getString("correo_destino"),
                                rs.getString("token"),
                                rs.getString("contenido"),
                                rs.getObject("fecha", LocalDate.class),
                                rs.getObject("hora_inicio", LocalTime.class),
                                rs.getObject("hora_fin", LocalTime.class),
                                rs.getString("especialidad_nombre"),
                                rs.getString("socio_nombre")
                        ),
                        envioId
                )
                .stream()
                .findFirst();
    }

    public Optional<Long> bloquearSiguienteEnvioPendiente() {
        return jdbcTemplate.query(
                        """
                        SELECT id_envio
                        FROM public.envio_notificacion envio
                        JOIN public.notificacion notificacion
                          ON notificacion.id_notificacion = envio.id_notificacion
                        WHERE envio.estado = 'PENDIENTE'
                          AND notificacion.tipo = 'SUSPENSION'
                        ORDER BY envio.id_envio
                        LIMIT 1
                        FOR UPDATE OF envio SKIP LOCKED
                        """,
                        (rs, rowNum) -> rs.getLong("id_envio")
                )
                .stream()
                .findFirst();
    }

    public boolean existeEnvio(Long envioId) {
        Boolean existe = jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.envio_notificacion
                    WHERE id_envio = ?
                )
                """,
                Boolean.class,
                envioId
        );
        return Boolean.TRUE.equals(existe);
    }

    public int marcarEnvio(Long envioId, String estado) {
        return jdbcTemplate.update(
                """
                UPDATE public.envio_notificacion
                SET estado = ?,
                    intentos = intentos + 1,
                    ultimo_intento_en = CURRENT_TIMESTAMP,
                    enviado_en = CASE WHEN ? = 'ENVIADO'
                                      THEN CURRENT_TIMESTAMP ELSE NULL END
                WHERE id_envio = ?
                """,
                estado,
                estado,
                envioId
        );
    }

    public List<Long> idsMedicos(List<RecursoTurno> recursos) {
        return recursos.stream().map(RecursoTurno::medicoId).distinct().sorted().toList();
    }

    public List<Long> idsConsultorios(List<RecursoTurno> recursos) {
        return recursos.stream()
                .map(RecursoTurno::consultorioId)
                .distinct()
                .sorted()
                .toList();
    }

    private List<Object> parametros(
            LocalDate desde,
            LocalDate hasta,
            List<Long> idsSeleccionados,
            List<Long> medicos,
            List<Long> consultorios
    ) {
        List<Object> parametros = new ArrayList<>();
        parametros.add(desde);
        parametros.add(hasta);
        parametros.addAll(idsSeleccionados);
        parametros.addAll(medicos);
        parametros.addAll(consultorios);
        return parametros;
    }

    private String placeholders(int size) {
        if (size <= 0) {
            throw new IllegalArgumentException("La lista SQL no puede estar vacía");
        }
        return String.join(", ", java.util.Collections.nCopies(size, "?"));
    }

    private String hora(LocalTime hora) {
        return hora == null ? null : hora.toString();
    }

    public record TurnoFecha(
            Long id,
            Long patronId,
            LocalDate fecha,
            String estado,
            Long medicoId,
            Long especialidadId,
            Long consultorioId,
            String horaInicio,
            String horaFin,
            int consultasAgendadas
    ) {
    }

    public record ConsultaParaCancelar(
            Long id,
            Long socioId,
            Long numeroId,
            Long turnoId,
            LocalDate fecha,
            LocalTime horaInicio,
            LocalTime horaFin,
            int numero,
            String correo
    ) {
    }

    public record RecursoTurno(
            Long turnoId,
            Long patronId,
            LocalDate fecha,
            String estado,
            Long medicoId,
            boolean medicoHabilitado,
            Long especialidadId,
            Long consultorioId,
            Long numeroId,
            int numero,
            LocalTime horaInicio,
            LocalTime horaFin
    ) {
    }

    public record NumeroExistente(
            Long turnoId,
            LocalDate fecha,
            Long medicoId,
            Long consultorioId,
            int numero,
            LocalTime horaInicio,
            LocalTime horaFin
    ) {
    }

    public record EnvioNotificacion(
            Long envioId,
            Long notificacionId,
            String canal,
            String correo,
            String token,
            String contenido,
            LocalDate fecha,
            LocalTime horaInicio,
            LocalTime horaFin,
            String especialidad,
            String socioNombre
    ) {
    }
}
