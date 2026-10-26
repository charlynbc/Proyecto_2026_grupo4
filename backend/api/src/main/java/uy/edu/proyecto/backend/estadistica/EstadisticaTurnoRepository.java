package uy.edu.proyecto.backend.estadistica;

import java.sql.Date;
import java.time.LocalDate;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class EstadisticaTurnoRepository {

    /** Conteos crudos de un turno semanal; el porcentaje lo calcula el servicio. */
    public record Fila(
            long turnoSemanalId,
            EstadisticaTurnoDTO.Persona medico,
            Especialidad especialidad,
            EstadisticaTurnoDTO.Consultorio consultorio,
            int diaSemana,
            long fechasActivas,
            long numerosOfrecidos,
            long numerosOcupados
    ) {
    }

    // Unidad: patron semanal (turno_semanal) cuya vigencia toca el periodo.
    // Fechas activas: turno.estado = 'ACTIVO' (una fecha suspendida y luego rehabilitada vuelve a ACTIVO).
    // Ofrecidos: numeros de esas fechas. Ocupado: existe al menos una consulta no cancelada del numero;
    // el EXISTS evalua una vez por numero, de modo que las reservas historicas no se duplican.
    // AGENDADA cubre tambien los estados derivados NO_ASISTIO y NO_ATENDIDA (no se persisten).
    private static final String SQL = """
            SELECT ts.id_turno_semanal,
                   ts.dia_semana,
                   e.id_especialidad,
                   e.nombre AS especialidad_nombre,
                   e.requiere_pase,
                   ts.id_medico,
                   p.nombre AS medico_nombre,
                   p.apellido AS medico_apellido,
                   co.id_consultorio,
                   co.nombre AS consultorio_nombre,
                   co.ubicacion AS consultorio_ubicacion,
                   COUNT(DISTINCT t.id_turno) AS fechas_activas,
                   COUNT(n.id_numero) AS ofrecidos,
                   COALESCE(SUM(CASE WHEN EXISTS (
                                  SELECT 1
                                  FROM public.consulta c
                                  WHERE c.id_numero = n.id_numero
                                    AND c.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
                              ) THEN 1 ELSE 0 END), 0) AS ocupados
            FROM public.turno_semanal ts
            JOIN public.especialidad e ON e.id_especialidad = ts.id_especialidad
            JOIN public.cuenta m ON m.id_cuenta = ts.id_medico
            JOIN public.persona p ON p.ci = m.ci
            JOIN public.consultorio co ON co.id_consultorio = ts.id_consultorio
            LEFT JOIN public.turno t
                   ON t.id_turno_semanal = ts.id_turno_semanal
                  AND t.estado = 'ACTIVO'
                  AND t.fecha >= ?
                  AND t.fecha <= ?
            LEFT JOIN public.numero n ON n.id_turno = t.id_turno
            WHERE ts.fecha_inicio <= ?
              AND ts.fecha_fin >= ?
            GROUP BY ts.id_turno_semanal, ts.dia_semana, e.id_especialidad, e.nombre, e.requiere_pase,
                     ts.id_medico, p.nombre, p.apellido, co.id_consultorio, co.nombre, co.ubicacion
            ORDER BY e.nombre ASC, ts.dia_semana ASC, ts.id_turno_semanal ASC
            """;

    private final JdbcTemplate jdbcTemplate;

    public EstadisticaTurnoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<Fila> contarUtilizacion(LocalDate desde, LocalDate hasta) {
        Date sqlDesde = Date.valueOf(desde);
        Date sqlHasta = Date.valueOf(hasta);
        return jdbcTemplate.query(
                SQL,
                (rs, rowNum) -> new Fila(
                        rs.getLong("id_turno_semanal"),
                        new EstadisticaTurnoDTO.Persona(
                                rs.getLong("id_medico"),
                                rs.getString("medico_nombre"),
                                rs.getString("medico_apellido")
                        ),
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("especialidad_nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        new EstadisticaTurnoDTO.Consultorio(
                                rs.getLong("id_consultorio"),
                                rs.getString("consultorio_nombre"),
                                rs.getString("consultorio_ubicacion")
                        ),
                        rs.getInt("dia_semana"),
                        rs.getLong("fechas_activas"),
                        rs.getLong("ofrecidos"),
                        rs.getLong("ocupados")
                ),
                sqlDesde,
                sqlHasta,
                sqlHasta,
                sqlDesde
        );
    }
}
