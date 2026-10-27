package uy.edu.proyecto.backend.estadistica;

import java.sql.Date;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class EstadisticaConsultaRepository {

    // Periodo sobre la fecha de la consulta medica (turno.fecha), no sobre agendada_en.
    // Estado efectivo: mismas reglas que ConsultaRepository y AgendaConsultaRepository. Una consulta
    // AGENDADA sin resultado cuyo dia ya termino (turno.fecha < hoy) es NO_ATENDIDA si el socio tiene aviso
    // de llegada ese dia y NO_ASISTIO si no. Nada se persiste. Cada fila de consulta se une por clave
    // primaria con un unico numero y turno, y el aviso se consulta con EXISTS: no hay duplicados.
    private static final String SQL = """
            SELECT CASE
                       WHEN c.estado = 'AGENDADA'
                            AND c.fecha_resultado IS NULL
                            AND t.fecha < ? THEN
                           CASE
                               WHEN EXISTS (
                                   SELECT 1
                                   FROM public.aviso_llegada a
                                   WHERE a.id_socio = c.id_socio
                                     AND a.fecha = t.fecha
                               ) THEN 'NO_ATENDIDA'
                               ELSE 'NO_ASISTIO'
                           END
                       ELSE c.estado
                   END AS estado_efectivo,
                   COUNT(*) AS cantidad
            FROM public.consulta c
            JOIN public.numero n ON n.id_numero = c.id_numero
            JOIN public.turno t ON t.id_turno = n.id_turno
            WHERE t.fecha >= ?
              AND t.fecha <= ?
            GROUP BY 1
            """;

    private final JdbcTemplate jdbcTemplate;

    public EstadisticaConsultaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** Cantidad por estado efectivo; los estados sin consultas no figuran en el mapa. */
    public Map<String, Long> contarPorEstado(LocalDate desde, LocalDate hasta, LocalDate hoy) {
        Map<String, Long> cantidades = new HashMap<>();
        jdbcTemplate.query(
                SQL,
                rs -> {
                    cantidades.put(rs.getString("estado_efectivo"), rs.getLong("cantidad"));
                },
                Date.valueOf(hoy),
                Date.valueOf(desde),
                Date.valueOf(hasta)
        );
        return cantidades;
    }
}
