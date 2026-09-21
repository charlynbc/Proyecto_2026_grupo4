package uy.edu.proyecto.backend.reserva;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ReservaConsultaRepository {

    private final JdbcTemplate jdbcTemplate;

    public ReservaConsultaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<ReservaHistorial> listarPorUsuario(Long usuarioId) {
        String sql = """
                SELECT r.id, r.estado, r.fecha_creacion, r.fecha_cancelacion,
                       h.id AS horario_id, h.inicio, h.fin,
                       p.id AS profesional_id, p.nombre AS profesional
                FROM "POC".reserva r
                JOIN "POC".horario h ON h.id = r.horario_id
                JOIN "POC".profesional p ON p.id = h.profesional_id
                WHERE r.usuario_id = ?
                ORDER BY h.inicio DESC, r.id DESC
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new ReservaHistorial(
                        rs.getLong("id"),
                        rs.getString("estado"),
                        rs.getObject("fecha_creacion", OffsetDateTime.class),
                        rs.getObject("fecha_cancelacion", OffsetDateTime.class),
                        rs.getLong("horario_id"),
                        rs.getObject("inicio", OffsetDateTime.class),
                        rs.getObject("fin", OffsetDateTime.class),
                        rs.getLong("profesional_id"),
                        rs.getString("profesional")
                ),
                usuarioId
        );
    }

    public Optional<ReservaCancelada> cancelar(Long reservaId, Long usuarioId) {
        String sql = """
                UPDATE "POC".reserva
                SET estado = 'CANCELADA', fecha_cancelacion = CURRENT_TIMESTAMP
                WHERE id = ?
                  AND usuario_id = ?
                  AND estado = 'ACTIVA'
                RETURNING id, horario_id, estado, fecha_cancelacion
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new ReservaCancelada(
                        rs.getLong("id"),
                        rs.getLong("horario_id"),
                        rs.getString("estado"),
                        rs.getObject("fecha_cancelacion", OffsetDateTime.class)
                ),
                reservaId,
                usuarioId
        ).stream().findFirst();
    }
}