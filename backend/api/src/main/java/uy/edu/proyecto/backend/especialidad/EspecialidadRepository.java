package uy.edu.proyecto.backend.especialidad;

import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import uy.edu.proyecto.backend.busqueda.TextoBusqueda;

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

    public List<Especialidad> listarFiltradas(String nombre, Boolean requierePase, String orden) {
        StringBuilder sql = new StringBuilder("""
                SELECT id_especialidad, nombre, requiere_pase
                FROM public.especialidad
                WHERE TRUE
                """);
        List<Object> params = new ArrayList<>();
        if (nombre != null && !nombre.isBlank()) {
            sql.append(" AND " + TextoBusqueda.contiene("nombre"));
            params.add(TextoBusqueda.patron(nombre));
        }
        if (requierePase != null) {
            sql.append(" AND requiere_pase = ?");
            params.add(requierePase);
        }
        sql.append(" ORDER BY ");
        sql.append("fechaAlta".equals(orden) ? "fecha_alta" : "nombre");
        sql.append(", id_especialidad");
        return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> new Especialidad(
                rs.getLong("id_especialidad"),
                rs.getString("nombre"),
                rs.getBoolean("requiere_pase")
        ), params.toArray());
    }

    /**
     * Devuelve las especialidades cuyo nombre (sin distinguir mayusculas)
     * este en la coleccion dada, indexadas por nombre en minusculas.
     * La unicidad la respalda el indice uq_especialidad_nombre.
     */
    public Map<String, Especialidad> buscarPorNombresLower(
            Collection<String> nombres
    ) {
        if (nombres == null || nombres.isEmpty()) {
            return Map.of();
        }

        List<String> normalizados = nombres.stream()
                .map(nombre -> nombre.trim().toLowerCase(Locale.ROOT))
                .distinct()
                .toList();

        String placeholders = normalizados.stream()
                .map(ignored -> "?")
                .collect(Collectors.joining(", "));

        Map<String, Especialidad> encontradas = new HashMap<>();
        jdbcTemplate.query(
                """
                SELECT id_especialidad, nombre, requiere_pase
                FROM public.especialidad
                WHERE lower(nombre) IN (%s)
                """.formatted(placeholders),
                (rs, rowNum) -> {
                    Especialidad especialidad = new Especialidad(
                            rs.getLong("id_especialidad"),
                            rs.getString("nombre"),
                            rs.getBoolean("requiere_pase")
                    );
                    encontradas.put(
                            especialidad.nombre().toLowerCase(Locale.ROOT),
                            especialidad
                    );
                    return especialidad;
                },
                normalizados.toArray()
        );
        return encontradas;
    }

    public java.util.Optional<Especialidad> buscarPorId(long id) {
        String sql = """
                SELECT id_especialidad, nombre, requiere_pase
                FROM public.especialidad
                WHERE id_especialidad = ?
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new Especialidad(
                        rs.getLong("id_especialidad"),
                        rs.getString("nombre"),
                        rs.getBoolean("requiere_pase")
                ),
                id
        ).stream().findFirst();
    }

    /** Busca por nombre sin distinguir mayusculas (unicidad de RF-29/RF-38). */
    public java.util.Optional<Especialidad> buscarPorNombreLower(String nombre) {
        String sql = """
                SELECT id_especialidad, nombre, requiere_pase
                FROM public.especialidad
                WHERE lower(nombre) = lower(?)
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new Especialidad(
                        rs.getLong("id_especialidad"),
                        rs.getString("nombre"),
                        rs.getBoolean("requiere_pase")
                ),
                nombre
        ).stream().findFirst();
    }

    public Especialidad actualizar(
            long id,
            String nombre,
            boolean requierePase
    ) {
        String sql = """
                UPDATE public.especialidad
                SET nombre = ?, requiere_pase = ?
                WHERE id_especialidad = ?
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
                requierePase,
                id
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
