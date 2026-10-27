package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class ConsultaRepository {

    private static final String HISTORIAL_CTE = """
            WITH consulta_historial AS (
                SELECT consulta.id_consulta,
                       consulta.id_socio,
                       CASE
                           WHEN consulta.estado = 'AGENDADA'
                                AND consulta.fecha_resultado IS NULL
                                AND turno.fecha < ? THEN
                               CASE
                                   WHEN EXISTS (
                                       SELECT 1
                                       FROM public.aviso_llegada aviso
                                       WHERE aviso.id_socio = consulta.id_socio
                                         AND aviso.fecha = turno.fecha
                                   ) THEN 'NO_ATENDIDA'
                                   ELSE 'NO_ASISTIO'
                               END
                           ELSE consulta.estado
                       END AS estado,
                       turno.fecha,
                       numero.numero,
                       numero.hora_inicio,
                       numero.hora_fin,
                       semanal.id_medico,
                       persona.nombre AS medico_nombre,
                       persona.apellido AS medico_apellido,
                       semanal.id_especialidad,
                       especialidad.nombre AS especialidad_nombre,
                       especialidad.requiere_pase,
                       turno.id_consultorio,
                       consultorio.nombre AS consultorio_nombre,
                       consultorio.ubicacion AS consultorio_ubicacion,
                       consulta.id_pase,
                       consulta.agendada_en,
                       consulta.cancelada_en,
                       consulta.motivo_cancelacion
                FROM public.consulta consulta
                JOIN public.numero numero
                  ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno
                  ON turno.id_turno = numero.id_turno
                JOIN public.turno_semanal semanal
                  ON semanal.id_turno_semanal = turno.id_turno_semanal
                JOIN public.cuenta medico
                  ON medico.id_cuenta = semanal.id_medico
                JOIN public.persona persona
                  ON persona.ci = medico.ci
                JOIN public.especialidad especialidad
                  ON especialidad.id_especialidad = semanal.id_especialidad
                JOIN public.consultorio consultorio
                  ON consultorio.id_consultorio = turno.id_consultorio
                WHERE consulta.id_socio = ?
            )
            """;

    private static final org.springframework.jdbc.core.RowMapper<ConsultaDTO>
            HISTORIAL_ROW_MAPPER = (rs, rowNum) -> new ConsultaDTO(
                    rs.getLong("id_consulta"),
                    rs.getString("estado"),
                    rs.getObject("fecha", LocalDate.class),
                    rs.getInt("numero"),
                    rs.getObject("hora_inicio", LocalTime.class).toString(),
                    rs.getObject("hora_fin", LocalTime.class).toString(),
                    new ConsultaDTO.MedicoRef(
                            rs.getLong("id_medico"),
                            rs.getString("medico_nombre"),
                            rs.getString("medico_apellido")
                    ),
                    new Especialidad(
                            rs.getLong("id_especialidad"),
                            rs.getString("especialidad_nombre"),
                            rs.getBoolean("requiere_pase")
                    ),
                    new Consultorio(
                            rs.getLong("id_consultorio"),
                            rs.getString("consultorio_nombre"),
                            rs.getString("consultorio_ubicacion")
                    ),
                    (Long) rs.getObject("id_pase"),
                    rs.getObject("agendada_en", OffsetDateTime.class),
                    rs.getObject("cancelada_en", OffsetDateTime.class),
                    rs.getString("motivo_cancelacion")
            );

    private final JdbcTemplate jdbcTemplate;

    public ConsultaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean bloquearSocioHabilitado(Long idSocio) {
        return !jdbcTemplate.query(
                """
                SELECT id_cuenta
                FROM public.cuenta
                WHERE id_cuenta = ?
                  AND rol = 'SOCIO'
                  AND habilitada = TRUE
                  AND primer_ingreso_completado = TRUE
                FOR UPDATE
                """,
                (rs, rowNum) -> rs.getLong("id_cuenta"),
                idSocio
        ).isEmpty();
    }

    public Optional<NumeroParaAgendar> bloquearNumero(Long numeroId) {
        return jdbcTemplate.query(
                        """
                        SELECT n.id_numero, n.numero, n.hora_inicio, n.hora_fin,
                               t.id_turno, t.fecha, t.estado AS turno_estado,
                               ts.id_medico,
                               p.nombre AS medico_nombre,
                               p.apellido AS medico_apellido,
                               e.id_especialidad, e.nombre AS especialidad_nombre,
                               e.requiere_pase,
                               c.id_consultorio, c.nombre AS consultorio_nombre,
                               c.ubicacion AS consultorio_ubicacion,
                               medico.habilitada AS medico_habilitado,
                               (
                                   (t.fecha + n.hora_inicio)
                                       AT TIME ZONE 'America/Montevideo'
                                   >= CURRENT_TIMESTAMP + INTERVAL '2 hours'
                                   AND
                                   (t.fecha + n.hora_inicio)
                                       AT TIME ZONE 'America/Montevideo'
                                   <= CURRENT_TIMESTAMP + INTERVAL '30 days'
                               ) AS ventana_valida
                        FROM public.numero n
                        JOIN public.turno t ON t.id_turno = n.id_turno
                        JOIN public.turno_semanal ts
                          ON ts.id_turno_semanal = t.id_turno_semanal
                        JOIN public.cuenta medico
                          ON medico.id_cuenta = ts.id_medico
                        JOIN public.persona p ON p.ci = medico.ci
                        JOIN public.especialidad e
                          ON e.id_especialidad = ts.id_especialidad
                        JOIN public.consultorio c
                          ON c.id_consultorio = t.id_consultorio
                        WHERE n.id_numero = ?
                        FOR UPDATE OF t, n
                        """,
                        (rs, rowNum) -> new NumeroParaAgendar(
                                rs.getLong("id_numero"),
                                rs.getLong("numero"),
                                rs.getObject("hora_inicio", LocalTime.class),
                                rs.getObject("hora_fin", LocalTime.class),
                                rs.getLong("id_turno"),
                                rs.getObject("fecha", LocalDate.class),
                                rs.getString("turno_estado"),
                                rs.getLong("id_medico"),
                                rs.getString("medico_nombre"),
                                rs.getString("medico_apellido"),
                                new Especialidad(
                                        rs.getLong("id_especialidad"),
                                        rs.getString("especialidad_nombre"),
                                        rs.getBoolean("requiere_pase")
                                ),
                                new Consultorio(
                                        rs.getLong("id_consultorio"),
                                        rs.getString("consultorio_nombre"),
                                        rs.getString("consultorio_ubicacion")
                                ),
                                rs.getBoolean("medico_habilitado"),
                                rs.getBoolean("ventana_valida")
                        ),
                        numeroId
                )
                .stream()
                .findFirst();
    }

    public boolean medicoHabilitado(Long idMedico) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT habilitada
                FROM public.cuenta
                WHERE id_cuenta = ? AND rol = 'MEDICO'
                """,
                Boolean.class,
                idMedico
        ));
    }

    public long contarConsultasAgendadas(Long socioId) {
        Long cantidad = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM public.consulta
                WHERE id_socio = ? AND estado = 'AGENDADA'
                """,
                Long.class,
                socioId
        );
        return cantidad == null ? 0 : cantidad;
    }

    public boolean tieneConsultaAgendadaEnEspecialidad(
            Long socioId,
            Long especialidadId
    ) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.consulta consulta
                    JOIN public.numero numero
                      ON numero.id_numero = consulta.id_numero
                    JOIN public.turno turno ON turno.id_turno = numero.id_turno
                    JOIN public.turno_semanal semanal
                      ON semanal.id_turno_semanal = turno.id_turno_semanal
                    WHERE consulta.id_socio = ?
                      AND consulta.estado = 'AGENDADA'
                      AND semanal.id_especialidad = ?
                )
                """,
                Boolean.class,
                socioId,
                especialidadId
        ));
    }

    public boolean tieneConsultaSuperpuesta(
            Long socioId,
            LocalDate fecha,
            LocalTime inicio,
            LocalTime fin
    ) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.consulta consulta
                    JOIN public.numero existente
                      ON existente.id_numero = consulta.id_numero
                    JOIN public.turno turno
                      ON turno.id_turno = existente.id_turno
                    WHERE consulta.id_socio = ?
                      AND consulta.estado = 'AGENDADA'
                      AND turno.fecha = ?
                      AND existente.hora_inicio < ?
                      AND ? < existente.hora_fin
                )
                """,
                Boolean.class,
                socioId,
                fecha,
                fin,
                inicio
        ));
    }

    public Optional<PaseParaAgendar> bloquearPaseDisponible(
            Long paseId,
            Long socioId,
            Long especialidadId,
            LocalDate fechaConsulta
    ) {
        return jdbcTemplate.query(
                        """
                        SELECT pase.id_pase, pase.vence_el
                        FROM public.pase pase
                        JOIN public.atencion atencion
                          ON atencion.id_atencion = pase.id_atencion
                        JOIN public.consulta consulta
                          ON consulta.id_consulta = atencion.id_consulta
                        WHERE pase.id_pase = ?
                          AND consulta.id_socio = ?
                          AND pase.id_especialidad_destino = ?
                          AND pase.vence_el >= ?
                          AND NOT EXISTS (
                              SELECT 1
                              FROM public.consulta usada
                              WHERE usada.id_pase = pase.id_pase
                                AND usada.estado NOT IN (
                                    'CANCELADA_SOCIO',
                                    'CANCELADA_INSTITUCION'
                                )
                          )
                        FOR UPDATE OF pase
                        """,
                        (rs, rowNum) -> new PaseParaAgendar(
                                rs.getLong("id_pase"),
                                rs.getObject("vence_el", LocalDate.class)
                        ),
                        paseId,
                        socioId,
                        especialidadId,
                        fechaConsulta
                )
                .stream()
                .findFirst();
    }

    public Optional<ConsultaDTO> crear(
            Long socioId,
            NumeroParaAgendar numero,
            Long paseId
    ) {
        return jdbcTemplate.query(
                        """
                        INSERT INTO public.consulta (id_socio, id_numero, id_pase)
                        VALUES (?, ?, ?)
                        RETURNING id_consulta, estado, agendada_en, cancelada_en,
                                  motivo_cancelacion
                        """,
                        (rs, rowNum) -> new ConsultaDTO(
                                rs.getLong("id_consulta"),
                                rs.getString("estado"),
                                numero.fecha(),
                                (int) numero.numero(),
                                numero.horaInicio().toString(),
                                numero.horaFin().toString(),
                                new ConsultaDTO.MedicoRef(
                                        numero.idMedico(),
                                        numero.medicoNombre(),
                                        numero.medicoApellido()
                                ),
                                numero.especialidad(),
                                numero.consultorio(),
                                paseId,
                                rs.getObject(
                                        "agendada_en",
                                        OffsetDateTime.class
                                ),
                                rs.getObject(
                                        "cancelada_en",
                                        OffsetDateTime.class
                                ),
                                rs.getString("motivo_cancelacion")
                        ),
                        socioId,
                        numero.idNumero(),
                        paseId
                )
                .stream()
                .findFirst();
    }

    public Optional<ConsultaParaCancelar> bloquearConsultaDelSocio(
            Long socioId,
            Long consultaId
    ) {
        return jdbcTemplate.query(
                        """
                        SELECT consulta.estado, t.fecha, n.hora_inicio,
                               pase.vence_el
                        FROM public.consulta consulta
                        JOIN public.numero n ON n.id_numero = consulta.id_numero
                        JOIN public.turno t ON t.id_turno = n.id_turno
                        LEFT JOIN public.pase pase
                          ON pase.id_pase = consulta.id_pase
                        WHERE consulta.id_consulta = ?
                          AND consulta.id_socio = ?
                        FOR UPDATE OF consulta
                        """,
                        (rs, rowNum) -> new ConsultaParaCancelar(
                                rs.getString("estado"),
                                rs.getObject("fecha", LocalDate.class),
                                rs.getObject("hora_inicio", LocalTime.class),
                                rs.getObject("vence_el", LocalDate.class)
                        ),
                        consultaId,
                        socioId
                )
                .stream()
                .findFirst();
    }

    // Consulta separada del bloqueo: en READ COMMITTED ve un aviso confirmado mientras se esperaba el bloqueo.
    public boolean existeAvisoLlegada(Long socioId, LocalDate fecha) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.aviso_llegada
                    WHERE id_socio = ? AND fecha = ?
                )
                """,
                Boolean.class,
                socioId,
                fecha
        ));
    }

    public Optional<OffsetDateTime> cancelarPorSocio(
            Long consultaId,
            Long socioId
    ) {
        return jdbcTemplate.query(
                        """
                        UPDATE public.consulta
                        SET estado = 'CANCELADA_SOCIO',
                            cancelada_por = ?,
                            cancelada_en = CURRENT_TIMESTAMP
                        WHERE id_consulta = ?
                          AND id_socio = ?
                          AND estado = 'AGENDADA'
                        RETURNING cancelada_en
                        """,
                        (rs, rowNum) -> rs.getObject("cancelada_en", OffsetDateTime.class),
                        socioId,
                        consultaId,
                        socioId
                )
                .stream()
                .findFirst();
    }

    public void crearNotificacionAgenda(Long consultaId) {
        jdbcTemplate.update(
                """
                INSERT INTO public.notificacion (id_consulta, tipo, contenido)
                VALUES (?, 'AGENDA', 'Consulta agendada')
                """,
                consultaId
        );
    }

    public ConsultaHistorialPageResponse listarHistorial(
            Long socioId,
            ConsultaHistorialFiltro filtro,
            LocalDate hoyUruguay
    ) {
        List<Object> parametros = new ArrayList<>();
        String where = filtrosHistorial(socioId, filtro, hoyUruguay, parametros);
        long total = jdbcTemplate.queryForObject(
                HISTORIAL_CTE
                        + "SELECT COUNT(*) FROM consulta_historial"
                        + where,
                Long.class,
                parametros.toArray()
        );

        String columnaOrden = switch (filtro.orden()) {
            case "fecha" -> "fecha";
            case "especialidad" -> "especialidad_nombre";
            default -> throw new IllegalArgumentException(
                    "El orden debe validarse antes de consultar el repositorio"
            );
        };
        String sentidoOrden = switch (filtro.sentido()) {
            case "asc" -> "ASC";
            case "desc" -> "DESC";
            default -> throw new IllegalArgumentException(
                    "El sentido debe validarse antes de consultar el repositorio"
            );
        };

        List<Object> paginaParametros = new ArrayList<>(parametros);
        paginaParametros.add(filtro.size());
        paginaParametros.add((long) filtro.page() * filtro.size());
        List<ConsultaDTO> items = jdbcTemplate.query(
                HISTORIAL_CTE
                        + """
                        SELECT *
                        FROM consulta_historial
                        """
                        + where
                        + " ORDER BY " + columnaOrden + " " + sentidoOrden
                        + ", id_consulta " + sentidoOrden
                        + " LIMIT ? OFFSET ?",
                HISTORIAL_ROW_MAPPER,
                paginaParametros.toArray()
        );
        return new ConsultaHistorialPageResponse(
                items,
                filtro.page(),
                filtro.size(),
                total
        );
    }

    public Optional<ConsultaDTO> obtenerHistorialDelSocio(
            Long socioId,
            Long consultaId,
            LocalDate hoyUruguay
    ) {
        return jdbcTemplate.query(
                        HISTORIAL_CTE
                                + """
                                SELECT *
                                FROM consulta_historial
                                WHERE id_consulta = ?
                                """,
                        HISTORIAL_ROW_MAPPER,
                        hoyUruguay,
                        socioId,
                        consultaId
                )
                .stream()
                .findFirst();
    }

    private String filtrosHistorial(
            Long socioId,
            ConsultaHistorialFiltro filtro,
            LocalDate hoyUruguay,
            List<Object> parametros
    ) {
        parametros.add(hoyUruguay);
        parametros.add(socioId);
        StringBuilder where = new StringBuilder(" WHERE TRUE");
        if (filtro.estado() != null) {
            where.append(" AND estado = ?");
            parametros.add(filtro.estado());
        }
        if (filtro.fechaDesde() != null) {
            where.append(" AND fecha >= ?");
            parametros.add(filtro.fechaDesde());
        }
        if (filtro.fechaHasta() != null) {
            where.append(" AND fecha <= ?");
            parametros.add(filtro.fechaHasta());
        }
        if (filtro.especialidadId() != null) {
            where.append(" AND id_especialidad = ?");
            parametros.add(filtro.especialidadId());
        }
        if (filtro.medicoId() != null) {
            where.append(" AND id_medico = ?");
            parametros.add(filtro.medicoId());
        }
        return where.toString();
    }

    public record NumeroParaAgendar(
            Long idNumero,
            long numero,
            LocalTime horaInicio,
            LocalTime horaFin,
            Long idTurno,
            LocalDate fecha,
            String estadoTurno,
            Long idMedico,
            String medicoNombre,
            String medicoApellido,
            Especialidad especialidad,
            Consultorio consultorio,
            boolean medicoHabilitado,
            boolean ventanaValida
    ) {
    }

    public record ConsultaParaCancelar(
            String estado,
            LocalDate fecha,
            LocalTime horaInicio,
            LocalDate venceElPase
    ) {
    }

    public record PaseParaAgendar(Long id, LocalDate venceEl) {
    }
}
