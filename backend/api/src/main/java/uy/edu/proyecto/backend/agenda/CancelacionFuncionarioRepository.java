package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CancelacionFuncionarioRepository {
    private final JdbcTemplate jdbcTemplate;

    public CancelacionFuncionarioRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<Long> buscarSocio(Long consultaId) {
        return jdbcTemplate.query("""
                SELECT id_socio FROM public.consulta WHERE id_consulta = ?
                """, (rs, rowNum) -> rs.getLong("id_socio"), consultaId)
                .stream().findFirst();
    }

    public Optional<String> ciFuncionario(Long funcionarioId) {
        return jdbcTemplate.query("""
                SELECT ci FROM public.cuenta
                WHERE id_cuenta = ? AND rol = 'FUNCIONARIO' AND habilitada = TRUE
                """, (rs, rowNum) -> rs.getString("ci"), funcionarioId)
                .stream().findFirst();
    }

    public Optional<DatosConsulta> bloquearConsulta(Long consultaId, Long socioId) {
        return jdbcTemplate.query("""
                SELECT consulta.id_socio, socio.ci, socio.correo,
                       consulta.estado, turno.fecha, numero.hora_inicio, pase.vence_el
                FROM public.consulta consulta
                JOIN public.cuenta socio ON socio.id_cuenta = consulta.id_socio
                JOIN public.numero numero ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno ON turno.id_turno = numero.id_turno
                LEFT JOIN public.pase pase ON pase.id_pase = consulta.id_pase
                WHERE consulta.id_consulta = ? AND consulta.id_socio = ?
                FOR UPDATE OF consulta
                """, (rs, rowNum) -> new DatosConsulta(
                rs.getLong("id_socio"), rs.getString("ci"), rs.getString("correo"),
                rs.getString("estado"), rs.getObject("fecha", LocalDate.class),
                rs.getObject("hora_inicio", LocalTime.class),
                rs.getObject("vence_el", LocalDate.class)
        ), consultaId, socioId).stream().findFirst();
    }

    public Optional<OffsetDateTime> cancelar(Long consultaId, Long funcionarioId) {
        return jdbcTemplate.query("""
                UPDATE public.consulta
                SET estado = 'CANCELADA_SOCIO', cancelada_por = ?,
                    cancelada_en = CURRENT_TIMESTAMP
                WHERE id_consulta = ? AND estado = 'AGENDADA'
                RETURNING cancelada_en
                """, (rs, rowNum) -> rs.getObject("cancelada_en", OffsetDateTime.class),
                funcionarioId, consultaId).stream().findFirst();
    }

    public Long crearNotificacion(Long consultaId, LocalDate fecha) {
        return jdbcTemplate.queryForObject("""
                INSERT INTO public.notificacion (id_consulta, tipo, contenido)
                VALUES (?, 'CANCELACION', ?)
                RETURNING id_notificacion
                """, Long.class, consultaId,
                "Tu consulta del " + fecha + " fue cancelada a tu solicitud.");
    }

    public record DatosConsulta(
            Long socioId, String ciSocio, String correo, String estado,
            LocalDate fecha, LocalTime horaInicio, LocalDate venceElPase
    ) {
    }
}
