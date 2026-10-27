package uy.edu.proyecto.backend.usuario;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class UsuarioPadronRepository {

    private final JdbcTemplate jdbcTemplate;

    public UsuarioPadronRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public UsuarioCuentaPageResponse listar(
            String rol,
            String estado,
            String texto,
            int page,
            int size
    ) {
        StringBuilder sql = new StringBuilder(
                """
                SELECT c.id_cuenta,
                       p.ci,
                       p.nombre,
                       p.apellido,
                       c.rol,
                       c.correo,
                       CASE WHEN c.habilitada THEN 'ACTIVA' ELSE 'INACTIVA' END AS estado,
                       c.primer_ingreso_completado AS activada,
                       c.fecha_alta
                FROM public.cuenta c
                JOIN public.persona p ON p.ci = c.ci
                WHERE TRUE
                """
        );

        List<Object> parametros = new ArrayList<>();

        if (rol != null && !rol.isBlank()) {
            sql.append(" AND c.rol = ?");
            parametros.add(rol.trim().toUpperCase());
        }

        if (estado != null && !estado.isBlank()) {
            sql.append(" AND c.habilitada = ?");
            String estadoNormalizado = estado.trim().toUpperCase();
            parametros.add("ACTIVA".equals(estadoNormalizado));
        }

        if (texto != null && !texto.isBlank()) {
            String textoBusqueda = "%" + texto.trim() + "%";
            sql.append(
                    " AND (LOWER(p.ci) LIKE LOWER(?) OR LOWER(p.apellido) LIKE LOWER(?))"
            );
            parametros.add(textoBusqueda);
            parametros.add(textoBusqueda);
        }

        long total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM (" + sql + ") cuenta_filtrada",
                Long.class,
                parametros.toArray()
        );

        sql.append(" ORDER BY p.apellido ASC, c.fecha_alta DESC LIMIT ? OFFSET ?");
        parametros.add(size);
        parametros.add((long) page * size);

        List<UsuarioCuentaDTO> items = jdbcTemplate.query(
                sql.toString(),
                (rs, rowNum) -> new UsuarioCuentaDTO(
                        rs.getLong("id_cuenta"),
                        rs.getString("ci"),
                        rs.getString("nombre"),
                        rs.getString("apellido"),
                        rs.getString("rol"),
                        rs.getString("correo"),
                        rs.getString("estado"),
                        rs.getBoolean("activada"),
                        rs.getObject("fecha_alta", OffsetDateTime.class)
                ),
                parametros.toArray()
        );

        return new UsuarioCuentaPageResponse(items, page, size, total);
    }
}
