package uy.edu.proyecto.backend.auth;

import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class RefreshTokenRepository {

    private final JdbcTemplate jdbcTemplate;

    public RefreshTokenRepository(
            JdbcTemplate jdbcTemplate
    ) {
        this.jdbcTemplate = jdbcTemplate;
    }


    public void crear(
            Long usuarioId,
            String tokenHash,
            OffsetDateTime expiraEn
    ) {

        String sql = """
                INSERT INTO "POC".refresh_token
                    (
                        usuario_id,
                        token_hash,
                        expira_en
                    )

                VALUES (?, ?, ?)
                """;

        jdbcTemplate.update(
                sql,
                usuarioId,
                tokenHash,
                expiraEn
        );
    }


    public Optional<Long> rotar(
            String hashAnterior,
            String hashNuevo,
            OffsetDateTime nuevaExpiracion
    ) {

        String sql = """
                UPDATE "POC".refresh_token

                SET
                    token_hash = ?,
                    expira_en = ?,
                    creado_en = CURRENT_TIMESTAMP

                WHERE token_hash = ?
                  AND revocado = FALSE
                  AND expira_en > CURRENT_TIMESTAMP

                RETURNING usuario_id
                """;

        return jdbcTemplate
                .query(
                        sql,

                        (rs, rowNum) ->
                                rs.getLong(
                                        "usuario_id"
                                ),

                        hashNuevo,
                        nuevaExpiracion,
                        hashAnterior
                )
                .stream()
                .findFirst();
    }


    public void revocar(
            String tokenHash
    ) {

        String sql = """
                UPDATE "POC".refresh_token

                SET revocado = TRUE

                WHERE token_hash = ?
                """;

        jdbcTemplate.update(
                sql,
                tokenHash
        );
    }
}
