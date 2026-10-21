package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class ConsultaRepository {

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

    public void crearNotificacionAgenda(Long consultaId) {
        jdbcTemplate.update(
                """
                INSERT INTO public.notificacion (id_consulta, tipo, contenido)
                VALUES (?, 'AGENDA', 'Consulta agendada')
                """,
                consultaId
        );
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

    public record PaseParaAgendar(Long id, LocalDate venceEl) {
    }
}
