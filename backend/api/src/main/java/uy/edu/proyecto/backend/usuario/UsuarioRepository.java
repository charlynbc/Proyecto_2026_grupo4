package uy.edu.proyecto.backend.usuario;

import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class UsuarioRepository {

    private final JdbcTemplate jdbcTemplate;

    public UsuarioRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Usuario crear(
            String nombre,
            String cedula,
            String passwordHash
    ) {

        String sql = """
                INSERT INTO "POC".usuario
                    (nombre, cedula, password_hash)
                VALUES (?, ?, ?)
                RETURNING id, nombre, cedula
                """;

        return jdbcTemplate.queryForObject(
                sql,
                (rs, rowNum) -> new Usuario(
                        rs.getLong("id"),
                        rs.getString("nombre"),
                        rs.getString("cedula")
                ),
                nombre,
                cedula,
                passwordHash
        );
    }

    public Optional<UsuarioCredenciales> buscarParaLogin(
            String cedula
    ) {

        String sql = """
                SELECT id, nombre, cedula, password_hash
                FROM "POC".usuario
                WHERE cedula = ?
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new UsuarioCredenciales(
                        rs.getLong("id"),
                        rs.getString("nombre"),
                        rs.getString("cedula"),
                        rs.getString("password_hash")
                ),
                cedula
        )
        .stream()
        .findFirst();
    }
}
