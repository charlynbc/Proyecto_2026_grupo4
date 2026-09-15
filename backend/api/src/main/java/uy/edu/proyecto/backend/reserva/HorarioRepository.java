package uy.edu.proyecto.backend.reserva;

import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class HorarioRepository {

    private final JdbcTemplate jdbcTemplate;

    public HorarioRepository(
            JdbcTemplate jdbcTemplate
    ) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<OffsetDateTime> buscarInicio(
            Long horarioId
    ) {

        String sql = """
                SELECT inicio
                FROM "POC".horario
                WHERE id = ?
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) ->
                        rs.getObject(
                                "inicio",
                                OffsetDateTime.class
                        ),
                horarioId
        )
        .stream()
        .findFirst();
    }
}
