package uy.edu.proyecto.backend.profesional;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ProfesionalRepository {

    private final JdbcTemplate jdbcTemplate;

    public ProfesionalRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Profesional> listar() {
        String sql = """
                SELECT id, nombre
                FROM "POC".profesional
                ORDER BY nombre, id
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new Profesional(
                        rs.getLong("id"),
                        rs.getString("nombre")
                )
        );
    }

    public List<HorarioDisponible> horariosDisponibles(
            Long profesionalId,
            OffsetDateTime desde,
            OffsetDateTime hasta
    ) {
        String sql = """
                SELECT h.id, h.profesional_id, h.inicio, h.fin
                FROM "POC".horario h
                WHERE h.profesional_id = ?
                  AND h.inicio >= ?
                  AND h.inicio < ?
                  AND h.inicio > CURRENT_TIMESTAMP
                  AND NOT EXISTS (
                      SELECT 1
                      FROM "POC".reserva r
                      WHERE r.horario_id = h.id
                        AND r.estado = 'ACTIVA'
                  )
                ORDER BY h.inicio, h.id
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new HorarioDisponible(
                        rs.getLong("id"),
                        rs.getLong("profesional_id"),
                        rs.getObject("inicio", OffsetDateTime.class),
                        rs.getObject("fin", OffsetDateTime.class)
                ),
                profesionalId,
                desde,
                hasta
        );
    }
}