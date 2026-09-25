package uy.edu.proyecto.backend.usuario;

import java.time.Instant;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class UsuarioRepository {

    private final JdbcTemplate jdbcTemplate;

    public UsuarioRepository(
            JdbcTemplate jdbcTemplate
    ) {
        this.jdbcTemplate = jdbcTemplate;
    }


    public Usuario crear(
            String nombre,
            String cedula,
            String passwordHash,
            String email,
            String rol
    ) {

        String sql = """
                INSERT INTO "POC".usuario
                    (
                        nombre,
                        cedula,
                        password_hash,
                                                email,
                        rol
                    )
                                VALUES (?, ?, ?, ?, ?)

                RETURNING
                    id,
                    nombre,
                    cedula,
                    email,
                    email_verificado,
                    rol
                """;

        return jdbcTemplate.queryForObject(
                sql,

                (rs, rowNum) ->
                        new Usuario(
                                rs.getLong("id"),
                                rs.getString("nombre"),
                                rs.getString("cedula"),
                                rs.getString("email"),
                                rs.getBoolean("email_verificado"),
                                rs.getString("rol")
                        ),

                nombre,
                cedula,
                passwordHash,
                rol
        );
    }


    public Optional<UsuarioCredenciales>
    buscarParaLogin(
            String cedula
    ) {

        String sql = """
                SELECT
                    id,
                    nombre,
                    cedula,
                    password_hash,
                    email_verificado,
                    rol

                FROM "POC".usuario

                WHERE cedula = ?
                """;

        return jdbcTemplate
                .query(
                        sql,

                        (rs, rowNum) ->
                                new UsuarioCredenciales(
                                        rs.getLong("id"),
                                        rs.getString("nombre"),
                                        rs.getString("cedula"),
                                        rs.getString(
                                                "password_hash"
                                        ),
                                        rs.getBoolean("email_verificado"),
                                        rs.getString("rol")
                                ),

                        cedula
                )
                .stream()
                .findFirst();
    }


    public Optional<UsuarioCredenciales>
    buscarPorId(
            Long usuarioId
    ) {

        String sql = """
                SELECT
                    id,
                    nombre,
                    cedula,
                    password_hash,
                    email_verificado,
                    rol

                FROM "POC".usuario

                WHERE id = ?
                """;

        return jdbcTemplate
                .query(
                        sql,

                        (rs, rowNum) ->
                                new UsuarioCredenciales(
                                        rs.getLong("id"),
                                        rs.getString("nombre"),
                                        rs.getString("cedula"),
                                        rs.getString(
                                                "password_hash"
                                        ),
                                        rs.getBoolean("email_verificado"),
                                        rs.getString("rol")
                                ),

                        usuarioId
                )
                .stream()
                                .findFirst();
        }


        public boolean existeEmail(String email) {

                String sql = """
                        SELECT EXISTS (
                            SELECT 1
                            FROM "POC".usuario
                            WHERE LOWER(email) = LOWER(?)
                        )
                        """;

                return Boolean.TRUE.equals(
                        jdbcTemplate.queryForObject(
                                sql,
                                Boolean.class,
                                email
                        )
                );
        }


        public void guardarTokenVerificacion(
                    Long usuarioId,
                    String tokenHash,
                    Instant expiraEn
            ) {

                jdbcTemplate.update(
                        """
                        INSERT INTO "POC".email_verification_token
                            (usuario_id, token_hash, expira_en)
                        VALUES (?, ?, ?)
                        """,
                        usuarioId,
                        tokenHash,
                        expiraEn
                );
        }


        public Optional<Long> consumirTokenVerificacion(
                    String tokenHash,
                    Instant ahora
            ) {

                return jdbcTemplate.query(
                        """
                        UPDATE "POC".email_verification_token
                        SET usado = TRUE
                        WHERE token_hash = ?
                          AND usado = FALSE
                          AND expira_en > ?
                        RETURNING usuario_id
                        """,
                        (rs, rowNum) -> rs.getLong("usuario_id"),
                        tokenHash,
                        ahora
                ).stream().findFirst();
        }


        public void marcarEmailVerificado(Long usuarioId) {

                jdbcTemplate.update(
                        """
                        UPDATE "POC".usuario
                        SET email_verificado = TRUE
                        WHERE id = ?
                        """,
                        usuarioId
                );
        }
}
