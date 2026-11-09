package uy.edu.proyecto.backend.estadistica;

import java.sql.Date;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class EstadisticaPaseRepository {
    public record Fila(Especialidad destino, long emitidos, long utilizados,
            long disponibles, long vencidos) {}

    private static final String SQL = """
            SELECT destino.id_especialidad, destino.nombre, destino.requiere_pase,
                   COUNT(x.id_pase) AS emitidos,
                   COUNT(x.id_pase) FILTER (WHERE x.utilizado) AS utilizados,
                   COUNT(x.id_pase) FILTER (WHERE NOT x.utilizado AND x.vence_el >= ?) AS disponibles,
                   COUNT(x.id_pase) FILTER (WHERE NOT x.utilizado AND x.vence_el < ?) AS vencidos
            FROM public.especialidad destino
            LEFT JOIN (
                SELECT pase.id_pase, pase.id_especialidad_destino, pase.vence_el,
                       EXISTS (
                           SELECT 1 FROM public.consulta uso
                           WHERE uso.id_pase = pase.id_pase
                             AND uso.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
                       ) AS utilizado
                FROM public.pase pase
                JOIN public.atencion a ON a.id_atencion = pase.id_atencion
                JOIN public.consulta origen ON origen.id_consulta = a.id_consulta
                JOIN public.numero n ON n.id_numero = origen.id_numero
                JOIN public.turno t ON t.id_turno = n.id_turno
                JOIN public.turno_semanal ts ON ts.id_turno_semanal = t.id_turno_semanal
                WHERE pase.emitido_en >= ? AND pase.emitido_en < ?
                  AND (?::bigint IS NULL OR ts.id_especialidad = ?)
            ) x ON x.id_especialidad_destino = destino.id_especialidad
            GROUP BY destino.id_especialidad, destino.nombre, destino.requiere_pase
            ORDER BY emitidos DESC, destino.nombre, destino.id_especialidad
            """;

    private final JdbcTemplate jdbc;

    public EstadisticaPaseRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Fila> contar(Instant desde, Instant hastaExclusivo, LocalDate hoy,
            Long especialidadOrigenId) {
        return jdbc.query(SQL, (rs, row) -> new Fila(
                new Especialidad(rs.getLong("id_especialidad"), rs.getString("nombre"),
                        rs.getBoolean("requiere_pase")),
                rs.getLong("emitidos"), rs.getLong("utilizados"),
                rs.getLong("disponibles"), rs.getLong("vencidos")),
                Date.valueOf(hoy), Date.valueOf(hoy), Timestamp.from(desde),
                Timestamp.from(hastaExclusivo), especialidadOrigenId, especialidadOrigenId);
    }
}
