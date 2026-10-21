package uy.edu.proyecto.backend.consultorio;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ConsultorioRepository {

    private final JdbcTemplate jdbcTemplate;

    public ConsultorioRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Consultorio> listar() {
        String sql = """
                SELECT id_consultorio, nombre, ubicacion
                FROM public.consultorio
                ORDER BY nombre
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new Consultorio(
                        rs.getLong("id_consultorio"),
                        rs.getString("nombre"),
                        rs.getString("ubicacion")
                )
        );
    }

    public Consultorio crear(String nombre, String ubicacion) {
        String sql = """
                INSERT INTO public.consultorio (nombre, ubicacion)
                VALUES (?, ?)
                RETURNING id_consultorio, nombre, ubicacion
                """;

        return jdbcTemplate.queryForObject(
                sql,
                (rs, rowNum) -> new Consultorio(
                        rs.getLong("id_consultorio"),
                        rs.getString("nombre"),
                        rs.getString("ubicacion")
                ),
                nombre,
                ubicacion
        );
    }
}
