package uy.edu.proyecto.backend.consultorio;

import java.util.List;
import java.util.ArrayList;

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

    public List<Consultorio> listarFiltrados(String nombre, String ubicacion, String orden) {
        StringBuilder sql = new StringBuilder("""
                SELECT id_consultorio, nombre, ubicacion
                FROM public.consultorio
                WHERE TRUE
                """);
        List<Object> params = new ArrayList<>();
        if (nombre != null && !nombre.isBlank()) {
            sql.append(" AND nombre ILIKE ?");
            params.add("%" + nombre + "%");
        }
        if (ubicacion != null && !ubicacion.isBlank()) {
            sql.append(" AND ubicacion ILIKE ?");
            params.add("%" + ubicacion + "%");
        }
        sql.append(" ORDER BY ");
        sql.append("ubicacion".equals(orden) ? "ubicacion" : "nombre");
        sql.append(", id_consultorio");
        return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> new Consultorio(
                rs.getLong("id_consultorio"),
                rs.getString("nombre"),
                rs.getString("ubicacion")
        ), params.toArray());
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
