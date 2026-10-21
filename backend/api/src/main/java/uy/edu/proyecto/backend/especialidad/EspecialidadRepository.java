package uy.edu.proyecto.backend.especialidad;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class EspecialidadRepository {

    private final JdbcTemplate jdbcTemplate;

    public EspecialidadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Especialidad> listar() {
        String sql = """
                SELECT id_especialidad, nombre, requiere_pase
                FROM public.especialidad
                ORDER BY nombre
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new Especialidad(
                        rs.getLong("id_especialidad"),
                        rs.getString("nombre"),
                        rs.getBoolean("requiere_pase")
                )
        );
    }

    public Especialidad crear(String nombre, boolean requierePase) {
        String sql = """
                INSERT INTO public.especialidad (nombre, requiere_pase)
                VALUES (?, ?)
                RETURNING id_especialidad, nombre, requiere_pase
                """;

        return jdbcTemplate.queryForObject(
                sql,
                (rs, rowNum) -> new Especialidad(
                        rs.getLong("id_especialidad"),
                        rs.getString("nombre"),
                        rs.getBoolean("requiere_pase")
                ),
                nombre,
                requierePase
        );
    }
}
