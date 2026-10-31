package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CancelacionMedicoRepository {

    private final JdbcTemplate jdbcTemplate;

    public CancelacionMedicoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<String> ciMedico(Long medicoId) {
        return jdbcTemplate.query("""
                SELECT ci FROM public.cuenta
                WHERE id_cuenta = ? AND rol = 'MEDICO' AND habilitada = TRUE
                """, (rs, rowNum) -> rs.getString("ci"), medicoId)
                .stream().findFirst();
    }

    // Solo consultas de turnos del médico: una ajena responde vacío para no revelar su existencia.
    public Optional<Long> buscarSocioEnConsultaDelMedico(Long consultaId, Long medicoId) {
        return jdbcTemplate.query("""
                SELECT consulta.id_socio
                FROM public.consulta consulta
                JOIN public.numero numero ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno ON turno.id_turno = numero.id_turno
                JOIN public.turno_semanal semanal
                  ON semanal.id_turno_semanal = turno.id_turno_semanal
                WHERE consulta.id_consulta = ? AND semanal.id_medico = ?
                """, (rs, rowNum) -> rs.getLong("id_socio"), consultaId, medicoId)
                .stream().findFirst();
    }

    public Optional<DatosConsulta> bloquearConsultaDelMedico(
            Long consultaId, Long socioId, Long medicoId) {
        return jdbcTemplate.query("""
                SELECT consulta.id_socio, socio.ci, socio.correo,
                       consulta.estado, turno.fecha, numero.hora_inicio, pase.vence_el
                FROM public.consulta consulta
                JOIN public.cuenta socio ON socio.id_cuenta = consulta.id_socio
                JOIN public.numero numero ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno ON turno.id_turno = numero.id_turno
                JOIN public.turno_semanal semanal
                  ON semanal.id_turno_semanal = turno.id_turno_semanal
                LEFT JOIN public.pase pase ON pase.id_pase = consulta.id_pase
                WHERE consulta.id_consulta = ? AND consulta.id_socio = ?
                  AND semanal.id_medico = ?
                FOR UPDATE OF consulta
                """, (rs, rowNum) -> new DatosConsulta(
                rs.getLong("id_socio"), rs.getString("ci"), rs.getString("correo"),
                rs.getString("estado"), rs.getObject("fecha", LocalDate.class),
                rs.getObject("hora_inicio", LocalTime.class),
                rs.getObject("vence_el", LocalDate.class)
        ), consultaId, socioId, medicoId).stream().findFirst();
    }

    // A diferencia de la cancelación del funcionario, el médico cancela como institución
    // y deja constancia del motivo (RF-27); no hay evento de suspensión.
    public Optional<OffsetDateTime> cancelarConsulta(
            Long consultaId, Long medicoId, String motivo) {
        return jdbcTemplate.query("""
                UPDATE public.consulta
                SET estado = 'CANCELADA_INSTITUCION', cancelada_por = ?,
                    cancelada_en = CURRENT_TIMESTAMP, motivo_cancelacion = ?
                WHERE id_consulta = ? AND estado = 'AGENDADA'
                RETURNING cancelada_en
                """, (rs, rowNum) -> rs.getObject("cancelada_en", OffsetDateTime.class),
                medicoId, motivo, consultaId).stream().findFirst();
    }

    public Long crearNotificacionCancelacion(Long consultaId, String contenido) {
        return jdbcTemplate.queryForObject("""
                INSERT INTO public.notificacion (id_consulta, tipo, contenido)
                VALUES (?, 'CANCELACION', ?)
                RETURNING id_notificacion
                """, Long.class, consultaId, contenido);
    }

    // Lectura complementaria sobre consultas ya bloqueadas por el circuito de suspensión:
    // CI del socio (conflicto de interés) y vencimiento del pase (devolución según RF-09).
    public List<ResumenCancelable> resumenCancelables(List<Long> consultaIds) {
        String placeholders = consultaIds.stream()
                .map(ignored -> "?")
                .collect(Collectors.joining(", "));
        return jdbcTemplate.query("""
                SELECT consulta.id_consulta, socio.ci, pase.vence_el
                FROM public.consulta consulta
                JOIN public.cuenta socio ON socio.id_cuenta = consulta.id_socio
                LEFT JOIN public.pase pase ON pase.id_pase = consulta.id_pase
                WHERE consulta.id_consulta IN (%s)
                ORDER BY consulta.id_consulta
                """.formatted(placeholders),
                (rs, rowNum) -> new ResumenCancelable(
                        rs.getLong("id_consulta"),
                        rs.getString("ci"),
                        rs.getObject("vence_el", LocalDate.class)
                ),
                consultaIds.toArray());
    }

    public record DatosConsulta(
            Long socioId, String ciSocio, String correo, String estado,
            LocalDate fecha, LocalTime horaInicio, LocalDate venceElPase
    ) {
    }

    public record ResumenCancelable(
            Long consultaId, String ciSocio, LocalDate venceElPase
    ) {
    }
}
