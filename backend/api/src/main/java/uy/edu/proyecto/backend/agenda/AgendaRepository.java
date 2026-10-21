package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class AgendaRepository {

    private final JdbcTemplate jdbcTemplate;

    public AgendaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean existeEspecialidad(Long especialidadId) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.especialidad
                    WHERE id_especialidad = ?
                )
                """,
                Boolean.class,
                especialidadId
        ));
    }

    public boolean existeMedico(Long medicoId) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.cuenta
                    WHERE id_cuenta = ?
                      AND rol = 'MEDICO'
                )
                """,
                Boolean.class,
                medicoId
        ));
    }

    public List<NumeroDisponibleDTO> consultarDisponibilidad(
            FiltroDisponibilidadDTO filtros
    ) {
        StringBuilder sql = new StringBuilder("""
                SELECT n.id_numero, t.id_turno, n.numero, t.fecha,
                       n.hora_inicio, n.hora_fin,
                       c.id_cuenta AS medico_id,
                       p.nombre AS medico_nombre,
                       p.apellido AS medico_apellido,
                       e.id_especialidad, e.nombre AS especialidad_nombre,
                       e.requiere_pase,
                       co.id_consultorio, co.nombre AS consultorio_nombre,
                       co.ubicacion AS consultorio_ubicacion
                FROM public.numero n
                JOIN public.turno t ON t.id_turno = n.id_turno
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.cuenta c ON c.id_cuenta = ts.id_medico
                JOIN public.persona p ON p.ci = c.ci
                JOIN public.especialidad e
                  ON e.id_especialidad = ts.id_especialidad
                JOIN public.consultorio co
                  ON co.id_consultorio = t.id_consultorio
                WHERE ts.id_especialidad = ?
                  AND t.estado = 'ACTIVO'
                  AND ((t.fecha + n.hora_inicio)
                       AT TIME ZONE 'America/Montevideo')
                      >= CURRENT_TIMESTAMP + INTERVAL '2 hours'
                  AND ((t.fecha + n.hora_inicio)
                       AT TIME ZONE 'America/Montevideo')
                      <= CURRENT_TIMESTAMP + INTERVAL '30 days'
                  AND NOT EXISTS (
                      SELECT 1
                      FROM public.consulta consulta
                      WHERE consulta.id_numero = n.id_numero
                        AND consulta.estado = 'AGENDADA'
                  )
                """);
        List<Object> parametros = new ArrayList<>();
        parametros.add(filtros.especialidadId());

        if (filtros.medicoId() != null) {
            sql.append(" AND ts.id_medico = ?");
            parametros.add(filtros.medicoId());
        }
        if (filtros.fechaDesde() != null) {
            sql.append(" AND t.fecha >= ?");
            parametros.add(filtros.fechaDesde());
        }
        if (filtros.fechaHasta() != null) {
            sql.append(" AND t.fecha <= ?");
            parametros.add(filtros.fechaHasta());
        }

        sql.append(ordenar(filtros.orden(), filtros.sentido()));

        return jdbcTemplate.query(
                sql.toString(),
                (rs, rowNum) -> new NumeroDisponibleDTO(
                        rs.getLong("id_numero"),
                        rs.getLong("id_turno"),
                        rs.getInt("numero"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getObject("hora_inicio", LocalTime.class).toString(),
                        rs.getObject("hora_fin", LocalTime.class).toString(),
                        new NumeroDisponibleDTO.MedicoRef(
                                rs.getLong("medico_id"),
                                rs.getString("medico_nombre"),
                                rs.getString("medico_apellido")
                        ),
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("especialidad_nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        new Consultorio(
                                rs.getLong("id_consultorio"),
                                rs.getString("consultorio_nombre"),
                                rs.getString("consultorio_ubicacion")
                        )
                ),
                parametros.toArray()
        );
    }

    private String ordenar(String orden, String sentido) {
        String direccion = sentido.equals("desc") ? "DESC" : "ASC";
        if (orden.equals("apellidoMedico")) {
            return """
                     ORDER BY p.apellido %s, p.nombre %s,
                              t.fecha %s, n.hora_inicio %s, n.id_numero %s
                    """.formatted(
                    direccion,
                    direccion,
                    direccion,
                    direccion,
                    direccion
            );
        }
        return """
                 ORDER BY t.fecha %s, n.hora_inicio %s,
                          p.apellido %s, p.nombre %s, n.id_numero %s
                """.formatted(
                direccion,
                direccion,
                direccion,
                direccion,
                direccion
        );
    }
}
