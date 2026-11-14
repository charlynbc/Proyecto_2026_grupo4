package uy.edu.proyecto.backend.consultorio;

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
            sql.append(" AND " + TextoBusqueda.contiene("nombre"));
            params.add(TextoBusqueda.patron(nombre));
        }
        if (ubicacion != null && !ubicacion.isBlank()) {
            sql.append(" AND " + TextoBusqueda.contiene("ubicacion"));
            params.add(TextoBusqueda.patron(ubicacion));
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

    /**
     * Devuelve los consultorios cuyo nombre (sin distinguir mayusculas) este
     * en la coleccion dada, indexados por nombre en minusculas. La carga
     * masiva (RF-34) trata los nombres como unicos sin distinguir mayusculas,
     * igual que la previsualizacion.
     */
    public Map<String, Consultorio> buscarPorNombresLower(
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

        Map<String, Consultorio> encontrados = new HashMap<>();
        jdbcTemplate.query(
                """
                SELECT id_consultorio, nombre, ubicacion
                FROM public.consultorio
                WHERE lower(nombre) IN (%s)
                """.formatted(placeholders),
                (rs, rowNum) -> {
                    Consultorio consultorio = new Consultorio(
                            rs.getLong("id_consultorio"),
                            rs.getString("nombre"),
                            rs.getString("ubicacion")
                    );
                    encontrados.put(
                            consultorio.nombre().toLowerCase(Locale.ROOT),
                            consultorio
                    );
                    return consultorio;
                },
                normalizados.toArray()
        );
        return encontrados;
    }

    public java.util.Optional<Consultorio> buscarPorId(long id) {
        String sql = """
                SELECT id_consultorio, nombre, ubicacion
                FROM public.consultorio
                WHERE id_consultorio = ?
                """;

        return jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new Consultorio(
                        rs.getLong("id_consultorio"),
                        rs.getString("nombre"),
                        rs.getString("ubicacion")
                ),
                id
        ).stream().findFirst();
    }

    public Consultorio actualizar(long id, String nombre, String ubicacion) {
        String sql = """
                UPDATE public.consultorio
                SET nombre = ?, ubicacion = ?
                WHERE id_consultorio = ?
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
                ubicacion,
                id
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
