package uy.edu.proyecto.backend.estadistica;

import java.sql.Date;
import java.time.LocalDate;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class EstadisticaInasistenciaRepository {
    public record Fila(long id, String nombre, String apellido, long atendidas,
            long noAsistio, long noSePresento, long noAtendidas) {}

    private final JdbcTemplate jdbc;

    public EstadisticaInasistenciaRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // Una consulta por fila; el aviso es unico por socio y fecha. El dia actual no entra.
    // Los estados derivados coinciden con RF-41.
    public List<Fila> contar(LocalDate desde, LocalDate hasta, LocalDate hoy, boolean porMedico) {
        String id = porMedico ? "ts.id_medico" : "e.id_especialidad";
        String nombre = porMedico ? "persona.nombre" : "e.nombre";
        String apellido = porMedico ? "persona.apellido" : "NULL::text";
        String sql = """
                WITH efectivas AS (
                    SELECT %s AS id, %s AS nombre, %s AS apellido,
                           CASE WHEN c.estado = 'AGENDADA' AND c.fecha_resultado IS NULL
                                     AND t.fecha < ?
                                THEN CASE WHEN aviso.id_aviso_llegada IS NULL
                                          THEN 'NO_ASISTIO' ELSE 'NO_ATENDIDA' END
                                ELSE c.estado END AS estado
                    FROM public.consulta c
                    JOIN public.numero n ON n.id_numero = c.id_numero
                    JOIN public.turno t ON t.id_turno = n.id_turno
                    JOIN public.turno_semanal ts ON ts.id_turno_semanal = t.id_turno_semanal
                    JOIN public.especialidad e ON e.id_especialidad = ts.id_especialidad
                    JOIN public.cuenta medico ON medico.id_cuenta = ts.id_medico
                    JOIN public.persona persona ON persona.ci = medico.ci
                    LEFT JOIN public.aviso_llegada aviso
                      ON aviso.id_socio = c.id_socio AND aviso.fecha = t.fecha
                    WHERE t.fecha BETWEEN ? AND ? AND t.fecha < ?
                      AND c.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
                )
                SELECT id, nombre, apellido,
                       COUNT(*) FILTER (WHERE estado = 'ATENDIDA') AS atendidas,
                       COUNT(*) FILTER (WHERE estado = 'NO_ASISTIO') AS no_asistio,
                       COUNT(*) FILTER (WHERE estado = 'NO_SE_PRESENTO') AS no_se_presento,
                       COUNT(*) FILTER (WHERE estado = 'NO_ATENDIDA') AS no_atendidas
                FROM efectivas
                GROUP BY id, nombre, apellido
                ORDER BY (COUNT(*) FILTER (WHERE estado IN ('NO_ASISTIO', 'NO_SE_PRESENTO')))::numeric
                         / NULLIF(COUNT(*), 0) DESC NULLS LAST, nombre, id
                """.formatted(id, nombre, apellido);
        return jdbc.query(sql, (rs, row) -> new Fila(rs.getLong("id"),
                rs.getString("nombre"), rs.getString("apellido"),
                rs.getLong("atendidas"), rs.getLong("no_asistio"),
                rs.getLong("no_se_presento"), rs.getLong("no_atendidas")),
                Date.valueOf(hoy), Date.valueOf(desde), Date.valueOf(hasta), Date.valueOf(hoy));
    }
}
