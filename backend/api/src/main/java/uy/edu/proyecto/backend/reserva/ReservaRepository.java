package uy.edu.proyecto.backend.reserva;

import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ReservaRepository {

    private final JdbcTemplate jdbcTemplate;

    public ReservaRepository(
            JdbcTemplate jdbcTemplate
    ) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<Reserva> crear(
            Long usuarioId,
            Long horarioId
    ) {

        String sql = """
                INSERT INTO "POC".reserva
                    (usuario_id, horario_id)
                SELECT ?, h.id
                FROM "POC".horario h
                WHERE h.id = ?
                  AND h.inicio > CURRENT_TIMESTAMP
                RETURNING
                    id,
                    horario_id,
                    estado,
                    fecha_creacion
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new Reserva(
                        rs.getLong("id"),
                        rs.getLong("horario_id"),
                        rs.getString("estado"),
                        rs.getObject(
                                "fecha_creacion",
                                OffsetDateTime.class
                        )
                ),
                usuarioId,
                horarioId
        )
        .stream()
        .findFirst();
    }
}
