package uy.edu.proyecto.backend.usuario;

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
            String rol
    ) {

        String sql = """
                INSERT INTO "POC".usuario
                    (
                        nombre,
                        cedula,
                        password_hash,
                        rol
                    )
                VALUES (?, ?, ?, ?)

                RETURNING
                    id,
                    nombre,
                    cedula,
                    rol
                """;

        return jdbcTemplate.queryForObject(
                sql,

                (rs, rowNum) ->
                        new Usuario(
                                rs.getLong("id"),
                                rs.getString("nombre"),
                                rs.getString("cedula"),
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
                                        rs.getString("rol")
                                ),

                        usuarioId
                )
                .stream()
                .findFirst();
    }
}
