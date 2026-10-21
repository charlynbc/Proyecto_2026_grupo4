package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class TurnoMedicoRepository {

    private final JdbcTemplate jdbcTemplate;

    public TurnoMedicoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<TurnosMedicoResponse.TurnoMedicoItem> listar(
            Long medicoId,
            LocalDate fecha
    ) {
        return jdbcTemplate.query(
                """
                SELECT t.id_turno, t.fecha,
                       MIN(n.hora_inicio) AS hora_inicio,
                       MAX(n.hora_fin) AS hora_fin,
                       e.id_especialidad, e.nombre AS especialidad_nombre,
                       e.requiere_pase,
                       c.id_consultorio, c.nombre AS consultorio_nombre,
                       c.ubicacion AS consultorio_ubicacion,
                       t.estado,
                       COUNT(n.id_numero) AS cantidad_numeros,
                       COUNT(consulta.id_consulta) AS cantidad_reservados
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.especialidad e
                  ON e.id_especialidad = ts.id_especialidad
                JOIN public.consultorio c
                  ON c.id_consultorio = t.id_consultorio
                LEFT JOIN public.numero n ON n.id_turno = t.id_turno
                LEFT JOIN public.consulta consulta
                  ON consulta.id_numero = n.id_numero
                 AND consulta.estado NOT IN (
                     'CANCELADA_SOCIO', 'CANCELADA_INSTITUCION'
                 )
                WHERE ts.id_medico = ? AND t.fecha = ?
                GROUP BY t.id_turno, t.fecha, e.id_especialidad,
                         e.nombre, e.requiere_pase, c.id_consultorio,
                         c.nombre, c.ubicacion, t.estado
                ORDER BY MIN(n.hora_inicio), t.id_turno
                """,
                (rs, rowNum) -> new TurnosMedicoResponse.TurnoMedicoItem(
                        rs.getLong("id_turno"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getObject("hora_inicio", LocalTime.class).toString(),
                        rs.getObject("hora_fin", LocalTime.class).toString(),
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("especialidad_nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        new Consultorio(
                                rs.getLong("id_consultorio"),
                                rs.getString("consultorio_nombre"),
                                rs.getString("consultorio_ubicacion")
                        ),
                        rs.getString("estado"),
                        rs.getLong("cantidad_numeros"),
                        rs.getLong("cantidad_reservados")
                ),
                medicoId,
                fecha
        );
    }

    public Optional<NumerosTurnoMedicoResponse> obtenerNumeros(
            Long medicoId,
            Long turnoId,
            Boolean llegada,
            String orden,
            String sentido,
            LocalDate fechaActual,
            LocalDate fechaMaxima,
            OffsetDateTime inicioMinimo
    ) {
        String filtroLlegada = "";
        if (llegada != null) {
            filtroLlegada = llegada
                    ? " AND consulta.id_consulta IS NOT NULL"
                            + " AND aviso.id_aviso_llegada IS NOT NULL"
                    : " AND consulta.id_consulta IS NOT NULL"
                            + " AND aviso.id_aviso_llegada IS NULL";
        }
        List<Object> parametros = List.of(
                fechaActual,
                fechaMaxima,
                inicioMinimo,
                medicoId,
                turnoId
        );

        List<NumeroBase> numeros = jdbcTemplate.query(
                """
                SELECT t.id_turno, t.fecha, t.estado,
                       e.id_especialidad, e.nombre AS especialidad_nombre,
                       e.requiere_pase,
                       c.id_consultorio, c.nombre AS consultorio_nombre,
                       c.ubicacion AS consultorio_ubicacion,
                       n.id_numero, n.numero,
                       n.hora_inicio, n.hora_fin,
                       consulta.id_consulta, consulta.estado AS consulta_estado,
                       paciente.ci AS paciente_ci,
                       persona.nombre AS paciente_nombre,
                       persona.apellido AS paciente_apellido,
                       aviso.registrada_en AS llegada_en,
                       (
                           t.estado = 'ACTIVO'
                           AND consulta.id_consulta IS NULL
                           AND t.fecha BETWEEN ? AND ?
                           AND ((t.fecha + n.hora_inicio)
                                AT TIME ZONE 'America/Montevideo') >= ?
                       ) AS disponible
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.especialidad e
                  ON e.id_especialidad = ts.id_especialidad
                JOIN public.consultorio c
                  ON c.id_consultorio = t.id_consultorio
                JOIN public.numero n ON n.id_turno = t.id_turno
                LEFT JOIN public.consulta consulta
                  ON consulta.id_numero = n.id_numero
                 AND consulta.estado NOT IN (
                     'CANCELADA_SOCIO', 'CANCELADA_INSTITUCION'
                 )
                LEFT JOIN public.cuenta paciente
                  ON paciente.id_cuenta = consulta.id_socio
                LEFT JOIN public.persona persona ON persona.ci = paciente.ci
                LEFT JOIN public.aviso_llegada aviso
                  ON aviso.id_socio = consulta.id_socio
                 AND aviso.fecha = t.fecha
                WHERE ts.id_medico = ? AND t.id_turno = ? %s
                """.formatted(filtroLlegada + " ORDER BY "
                        + ordenSql(orden, sentido)),
                (rs, rowNum) -> {
                    Long consultaId = rs.getObject(
                            "id_consulta",
                            Long.class
                    );
                    NumerosTurnoMedicoResponse.Consulta consulta =
                            consultaId == null
                                    ? null
                                    : new NumerosTurnoMedicoResponse.Consulta(
                                            consultaId,
                                            rs.getString("consulta_estado"),
                                            new NumerosTurnoMedicoResponse
                                                    .Paciente(
                                                    rs.getString("paciente_ci"),
                                                    rs.getString(
                                                            "paciente_nombre"
                                                    ),
                                                    rs.getString(
                                                            "paciente_apellido"
                                                    )
                                            ),
                                            rs.getObject(
                                                    "llegada_en",
                                                    OffsetDateTime.class
                                            )
                                    );
                    return new NumeroBase(
                            rs.getLong("id_turno"),
                            rs.getObject("fecha", LocalDate.class),
                            rs.getString("estado"),
                            new Especialidad(
                                    rs.getLong("id_especialidad"),
                                    rs.getString("especialidad_nombre"),
                                    rs.getBoolean("requiere_pase")
                            ),
                            new Consultorio(
                                    rs.getLong("id_consultorio"),
                                    rs.getString("consultorio_nombre"),
                                    rs.getString("consultorio_ubicacion")
                            ),
                            new NumerosTurnoMedicoResponse.NumeroItem(
                                    rs.getLong("id_numero"),
                                    rs.getInt("numero"),
                                    rs.getObject(
                                            "hora_inicio",
                                            LocalTime.class
                                    ).toString(),
                                    rs.getObject(
                                            "hora_fin",
                                            LocalTime.class
                                    ).toString(),
                                    consulta,
                                    rs.getBoolean("disponible")
                            )
                    );
                },
                parametros.toArray()
        );

        if (numeros.isEmpty()) {
            return Optional.empty();
        }
        NumeroBase primero = numeros.getFirst();
        return Optional.of(new NumerosTurnoMedicoResponse(
                new NumerosTurnoMedicoResponse.Turno(
                        primero.turnoId(),
                        primero.fecha(),
                        primero.especialidad(),
                        primero.consultorio(),
                        primero.estado()
                ),
                numeros.stream().map(NumeroBase::numero).toList()
        ));
    }

    private String ordenSql(String orden, String sentido) {
        String direccion = sentido.equals("desc") ? "DESC" : "ASC";
        if (orden.equals("horaLlegada")) {
            return "aviso.registrada_en " + direccion
                    + " NULLS LAST, n.hora_inicio, n.numero";
        }
        return "n.hora_inicio " + direccion + ", n.numero";
    }

    private record NumeroBase(
            Long turnoId,
            LocalDate fecha,
            String estado,
            Especialidad especialidad,
            Consultorio consultorio,
            NumerosTurnoMedicoResponse.NumeroItem numero
    ) {
    }
}
