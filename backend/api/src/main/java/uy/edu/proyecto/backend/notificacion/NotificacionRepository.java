package uy.edu.proyecto.backend.notificacion;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Lee la tabla notificacion para la lista del socio. No escribe: los avisos los crea cada operacion. */
@Repository
public class NotificacionRepository {
    record Fila(long id, String tipo, String contenido, OffsetDateTime creadaEn, long consultaId, Long atencionId) {
    }

    /**
     * Los avisos de las consultas de un socio (el destinatario sale de consulta.id_socio), sin los recordatorios
     * cuya hora todavia no llego. La paginacion, el filtro y el orden se resuelven en la base.
     */
    private static final String DESDE = """
            FROM public.notificacion n
            JOIN public.consulta c ON c.id_consulta = n.id_consulta
            """;

    private static final String FILTRO = """
            WHERE c.id_socio = ?
              AND (n.programada_para IS NULL OR n.programada_para <= ?)
            """;

    /**
     * Solo el listado trae la atencion (el conteo no la necesita). atencion tiene UNIQUE (id_consulta), asi que el
     * LEFT JOIN no duplica filas.
     */
    private static final String UNIR_ATENCION = """
            LEFT JOIN public.atencion a ON a.id_consulta = n.id_consulta
            """;

    private final JdbcTemplate jdbc;

    public NotificacionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    List<Fila> listar(long socioId, OffsetDateTime ahora, int page, int size) {
        return jdbc.query(
                """
                        SELECT n.id_notificacion, n.tipo, n.contenido, n.creada_en, n.id_consulta,
                               CASE WHEN n.tipo = 'HISTORIA_ACTUALIZADA' THEN a.id_atencion END AS atencion_id
                        """ + DESDE + UNIR_ATENCION + FILTRO + """
                        ORDER BY n.creada_en DESC, n.id_notificacion DESC
                        LIMIT ? OFFSET ?
                        """,
                (rs, fila) -> new Fila(
                        rs.getLong("id_notificacion"),
                        rs.getString("tipo"),
                        rs.getString("contenido"),
                        rs.getObject("creada_en", OffsetDateTime.class),
                        rs.getLong("id_consulta"),
                        rs.getObject("atencion_id", Long.class)),
                socioId, ahora, size, (long) page * size);
    }

    long total(long socioId, OffsetDateTime ahora) {
        Long total = jdbc.queryForObject("SELECT count(*) " + DESDE + FILTRO, Long.class, socioId, ahora);
        return total == null ? 0 : total;
    }
}
