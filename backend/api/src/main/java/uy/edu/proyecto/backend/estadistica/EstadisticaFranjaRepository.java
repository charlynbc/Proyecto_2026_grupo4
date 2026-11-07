package uy.edu.proyecto.backend.estadistica;

import java.sql.Date;
import java.time.LocalDate;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class EstadisticaFranjaRepository {
    public record Fila(int diaSemana, int hora, long cantidad) {}

    private static final String SQL = """
            SELECT EXTRACT(ISODOW FROM t.fecha)::integer AS dia_semana,
                   CASE WHEN ? = 'LLEGADAS'
                        THEN EXTRACT(HOUR FROM aviso.registrada_en AT TIME ZONE 'America/Montevideo')
                        ELSE EXTRACT(HOUR FROM n.hora_inicio) END::integer AS hora,
                   COUNT(*) AS cantidad
            FROM public.consulta c
            JOIN public.numero n ON n.id_numero = c.id_numero
            JOIN public.turno t ON t.id_turno = n.id_turno
            JOIN public.turno_semanal ts ON ts.id_turno_semanal = t.id_turno_semanal
            LEFT JOIN public.aviso_llegada aviso
              ON aviso.id_socio = c.id_socio AND aviso.fecha = t.fecha
            WHERE t.fecha BETWEEN ? AND ?
              AND c.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
              AND (? = 'CONSULTAS' OR aviso.id_aviso_llegada IS NOT NULL)
              AND (?::bigint IS NULL OR ts.id_especialidad = ?)
            GROUP BY 1, 2
            ORDER BY 1, 2
            """;

    private final JdbcTemplate jdbc;

    public EstadisticaFranjaRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Fila> contar(LocalDate desde, LocalDate hasta, String vista, Long especialidadId) {
        return jdbc.query(SQL, (rs, row) -> new Fila(rs.getInt("dia_semana"),
                rs.getInt("hora"), rs.getLong("cantidad")), vista, Date.valueOf(desde),
                Date.valueOf(hasta), vista, especialidadId, especialidadId);
    }
}
