package uy.edu.proyecto.backend.estadistica;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class EstadisticaEspecialidadRepository {

    // Cada consulta tiene un solo numero, un solo turno y un solo patron semanal:
    // la subconsulta no multiplica filas y el LEFT JOIN conserva las especialidades sin datos.
    private static final String SQL = """
            SELECT e.id_especialidad,
                   e.nombre,
                   e.requiere_pase,
                   COUNT(x.id_consulta) AS cantidad
            FROM public.especialidad e
            LEFT JOIN (
                SELECT c.id_consulta,
                       ts.id_especialidad
                FROM public.consulta c
                JOIN public.numero n ON n.id_numero = c.id_numero
                JOIN public.turno t ON t.id_turno = n.id_turno
                JOIN public.turno_semanal ts ON ts.id_turno_semanal = t.id_turno_semanal
                WHERE c.agendada_en >= ?
                  AND c.agendada_en < ?
            ) x ON x.id_especialidad = e.id_especialidad
            GROUP BY e.id_especialidad, e.nombre, e.requiere_pase
            ORDER BY cantidad DESC, e.nombre ASC, e.id_especialidad ASC
            """;

    private final JdbcTemplate jdbcTemplate;

    public EstadisticaEspecialidadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** Cuenta por fecha de agendamiento en el intervalo [desde, hastaExclusivo). */
    public List<EstadisticaEspecialidadDTO> contarAgendadas(
            Instant desde,
            Instant hastaExclusivo
    ) {
        return jdbcTemplate.query(
                SQL,
                (rs, rowNum) -> new EstadisticaEspecialidadDTO(
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        rs.getLong("cantidad")
                ),
                Timestamp.from(desde),
                Timestamp.from(hastaExclusivo)
        );
    }
}
