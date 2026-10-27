package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class AtencionRepository {

    private final JdbcTemplate jdbcTemplate;

    public AtencionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<Long> buscarSocioId(Long medicoId, Long consultaId) {
        List<Long> ids = jdbcTemplate.query(
                """
                SELECT consulta.id_socio
                FROM public.consulta consulta
                JOIN public.numero n ON n.id_numero = consulta.id_numero
                JOIN public.turno t ON t.id_turno = n.id_turno
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                WHERE ts.id_medico = ? AND consulta.id_consulta = ?
                """,
                (rs, rowNum) -> rs.getLong("id_socio"),
                medicoId,
                consultaId
        );
        return ids.stream().findFirst();
    }

    public boolean bloquearSocio(Long socioId) {
        return !jdbcTemplate.query(
                """
                SELECT id_cuenta
                FROM public.cuenta
                WHERE id_cuenta = ? AND rol = 'SOCIO'
                FOR UPDATE
                """,
                (rs, rowNum) -> rs.getLong("id_cuenta"),
                socioId
        ).isEmpty();
    }

    public Optional<ConsultaResultado> bloquearConsulta(
            Long medicoId,
            Long consultaId
    ) {
        List<ConsultaResultado> consultas = jdbcTemplate.query(
                """
                SELECT consulta.id_consulta, consulta.id_socio,
                       consulta.estado, t.fecha,
                       socio.ci AS socio_ci,
                       medico_persona.ci AS medico_ci
                FROM public.consulta consulta
                JOIN public.cuenta socio
                  ON socio.id_cuenta = consulta.id_socio
                JOIN public.numero n ON n.id_numero = consulta.id_numero
                JOIN public.turno t ON t.id_turno = n.id_turno
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.cuenta medico
                  ON medico.id_cuenta = ts.id_medico
                JOIN public.persona medico_persona
                  ON medico_persona.ci = medico.ci
                WHERE ts.id_medico = ? AND consulta.id_consulta = ?
                FOR UPDATE OF consulta
                """,
                (rs, rowNum) -> new ConsultaResultado(
                        rs.getLong("id_consulta"),
                        rs.getLong("id_socio"),
                        rs.getString("estado"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getString("socio_ci"),
                        rs.getString("medico_ci")
                ),
                medicoId,
                consultaId
        );
        return consultas.stream().findFirst();
    }

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

    public Optional<Especialidad> buscarEspecialidad(Long especialidadId) {
        List<Especialidad> especialidades = jdbcTemplate.query(
                """
                SELECT id_especialidad, nombre, requiere_pase
                FROM public.especialidad
                WHERE id_especialidad = ?
                """,
                (rs, rowNum) -> new Especialidad(
                        rs.getLong("id_especialidad"),
                        rs.getString("nombre"),
                        rs.getBoolean("requiere_pase")
                ),
                especialidadId
        );
        return especialidades.stream().findFirst();
    }

    public boolean tienePaseVigenteOConsultaAgendada(
            Long socioId,
            Long especialidadId,
            Long consultaId,
            LocalDate hoy
    ) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT (
                    EXISTS (
                        SELECT 1
                        FROM public.pase pase
                        JOIN public.atencion atencion
                          ON atencion.id_atencion = pase.id_atencion
                        JOIN public.consulta origen
                          ON origen.id_consulta = atencion.id_consulta
                        WHERE origen.id_socio = ?
                          AND pase.id_especialidad_destino = ?
                          AND pase.vence_el >= ?
                          AND NOT EXISTS (
                              SELECT 1
                              FROM public.consulta uso
                              WHERE uso.id_pase = pase.id_pase
                                AND uso.estado NOT IN (
                                    'CANCELADA_SOCIO',
                                    'CANCELADA_INSTITUCION'
                                )
                          )
                    )
                    OR EXISTS (
                        SELECT 1
                        FROM public.consulta pendiente
                        JOIN public.numero n
                          ON n.id_numero = pendiente.id_numero
                        JOIN public.turno t ON t.id_turno = n.id_turno
                        JOIN public.turno_semanal ts
                          ON ts.id_turno_semanal = t.id_turno_semanal
                        WHERE pendiente.id_socio = ?
                          AND pendiente.id_consulta <> ?
                          AND pendiente.estado = 'AGENDADA'
                          AND (t.fecha >= ?
                               OR pendiente.fecha_resultado IS NOT NULL)
                          AND ts.id_especialidad = ?
                    )
                )
                """,
                Boolean.class,
                socioId,
                especialidadId,
                hoy,
                socioId,
                consultaId,
                hoy,
                especialidadId
        ));
    }

    public Long crearAtencion(
            Long consultaId,
            Long medicoId,
            String afeccion,
            String tratamiento,
            String observaciones,
            OffsetDateTime registradaEn
    ) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.atencion (
                    id_consulta, id_medico, afeccion, tratamiento,
                    observaciones, registrada_en
                )
                VALUES (?, ?, ?, ?, ?, ?)
                RETURNING id_atencion
                """,
                Long.class,
                consultaId,
                medicoId,
                afeccion,
                tratamiento,
                observaciones,
                registradaEn
        );
    }

    public Long crearPase(
            Long atencionId,
            Especialidad especialidad,
            OffsetDateTime emitidoEn,
            LocalDate venceEl
    ) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.pase (
                    id_atencion, id_especialidad_destino, emitido_en, vence_el
                )
                VALUES (?, ?, ?, ?)
                RETURNING id_pase
                """,
                Long.class,
                atencionId,
                especialidad.id(),
                emitidoEn,
                venceEl
        );
    }

    public boolean registrarNoPresentacion(
            Long consultaId,
            Long medicoId,
            OffsetDateTime registradaEn
    ) {
        return jdbcTemplate.update(
                """
                UPDATE public.consulta
                SET estado = 'NO_SE_PRESENTO',
                    resultado_registrado_por = ?,
                    fecha_resultado = ?
                WHERE id_consulta = ? AND estado = 'AGENDADA'
                """,
                medicoId,
                registradaEn,
                consultaId
        ) == 1;
    }

    public boolean registrarAtendida(
            Long consultaId,
            Long medicoId,
            OffsetDateTime registradaEn
    ) {
        return jdbcTemplate.update(
                """
                UPDATE public.consulta
                SET estado = 'ATENDIDA',
                    resultado_registrado_por = ?,
                    fecha_resultado = ?
                WHERE id_consulta = ? AND estado = 'AGENDADA'
                """,
                medicoId,
                registradaEn,
                consultaId
        ) == 1;
    }

    public void crearNotificacionHistoriaActualizada(Long consultaId) {
        jdbcTemplate.update(
                """
                INSERT INTO public.notificacion (id_consulta, tipo, contenido)
                VALUES (?, 'HISTORIA_ACTUALIZADA', ?)
                """,
                consultaId,
                "Se actualizó la historia clínica de su consulta."
        );
    }

    public record ConsultaResultado(
            Long id,
            Long socioId,
            String estado,
            LocalDate fecha,
            String ciSocio,
            String ciMedico
    ) {
    }
}
