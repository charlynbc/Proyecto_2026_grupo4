package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class TurnoConsultaRepository {

    private final JdbcTemplate jdbcTemplate;

    public TurnoConsultaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean existeMedico(Long id) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1 FROM public.cuenta
                    WHERE id_cuenta = ? AND rol = 'MEDICO'
                )
                """,
                Boolean.class,
                id
        ));
    }

    public boolean existeEspecialidad(Long id) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1 FROM public.especialidad
                    WHERE id_especialidad = ?
                )
                """,
                Boolean.class,
                id
        ));
    }

    public TurnosPageResponse listar(FiltroTurnosDTO filtro) {
        FiltrosSql filtros = construirFiltros(filtro);
        Long totalResultado = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                %s
                """.formatted(filtros.where()),
                Long.class,
                filtros.parametros().toArray()
        );
        long total = totalResultado == null ? 0 : totalResultado;

        List<Object> parametrosPagina = new ArrayList<>(filtros.parametros());
        parametrosPagina.add(filtro.size());
        parametrosPagina.add((long) filtro.page() * filtro.size());
        List<TurnoFechaResponse> items = jdbcTemplate.query(
                """
                SELECT t.id_turno, t.id_turno_semanal, t.fecha,
                       EXTRACT(ISODOW FROM t.fecha)::integer AS dia_semana,
                       MIN(n.hora_inicio) AS hora_inicio,
                       MAX(n.hora_fin) AS hora_fin,
                       ts.id_medico, persona.nombre AS medico_nombre,
                       persona.apellido AS medico_apellido,
                       e.id_especialidad, e.nombre AS especialidad_nombre,
                       e.requiere_pase,
                       c.id_consultorio, c.nombre AS consultorio_nombre,
                       c.ubicacion AS consultorio_ubicacion,
                       COUNT(n.id_numero) AS cantidad_numeros,
                       t.estado
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.cuenta medico ON medico.id_cuenta = ts.id_medico
                JOIN public.persona persona ON persona.ci = medico.ci
                JOIN public.especialidad e
                  ON e.id_especialidad = ts.id_especialidad
                JOIN public.consultorio c
                  ON c.id_consultorio = t.id_consultorio
                LEFT JOIN public.numero n ON n.id_turno = t.id_turno
                %s
                GROUP BY t.id_turno, t.id_turno_semanal, t.fecha,
                         ts.id_medico, persona.nombre, persona.apellido,
                         e.id_especialidad, e.nombre, e.requiere_pase,
                         c.id_consultorio, c.nombre, c.ubicacion, t.estado
                ORDER BY %s
                LIMIT ? OFFSET ?
                """.formatted(
                        filtros.where(),
                        ordenSql(filtro.orden(), filtro.sentido())
                ),
                (rs, rowNum) -> new TurnoFechaResponse(
                        rs.getLong("id_turno"),
                        rs.getLong("id_turno_semanal"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getInt("dia_semana"),
                        rs.getObject("hora_inicio", LocalTime.class).toString(),
                        rs.getObject("hora_fin", LocalTime.class).toString(),
                        new TurnoFechaResponse.MedicoRef(
                                rs.getLong("id_medico"),
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
                        ),
                        rs.getLong("cantidad_numeros"),
                        rs.getString("estado")
                ),
                parametrosPagina.toArray()
        );
        return new TurnosPageResponse(items, filtro.page(), filtro.size(), total);
    }

    public Optional<TurnoSemanalResponse> obtenerPatron(Long id) {
        List<PatronBase> resultado = jdbcTemplate.query(
                """
                SELECT ts.id_turno_semanal, ts.dia_semana,
                       ts.fecha_inicio, ts.fecha_fin,
                       ts.id_medico, persona.nombre AS medico_nombre,
                       persona.apellido AS medico_apellido,
                       e.id_especialidad, e.nombre AS especialidad_nombre,
                       e.requiere_pase,
                       c.id_consultorio, c.nombre AS consultorio_nombre,
                       c.ubicacion AS consultorio_ubicacion,
                       (
                           SELECT COUNT(*)
                           FROM public.turno t
                           WHERE t.id_turno_semanal = ts.id_turno_semanal
                       ) AS cantidad_turnos,
                        (
                            SELECT COUNT(DISTINCT t2.id_consultorio) > 1
                            FROM public.turno t2
                            WHERE t2.id_turno_semanal = ts.id_turno_semanal
                              AND t2.fecha >= ?
                        ) AS consultorio_varia
                FROM public.turno_semanal ts
                JOIN public.cuenta medico ON medico.id_cuenta = ts.id_medico
                JOIN public.persona persona ON persona.ci = medico.ci
                JOIN public.especialidad e
                  ON e.id_especialidad = ts.id_especialidad
                JOIN public.consultorio c
                  ON c.id_consultorio = ts.id_consultorio
                WHERE ts.id_turno_semanal = ?
                """,
                (rs, rowNum) -> new PatronBase(
                        rs.getLong("id_turno_semanal"),
                        new TurnoSemanalResponse.MedicoRef(
                                rs.getLong("id_medico"),
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
                        ),
                        rs.getInt("dia_semana"),
                        rs.getObject("fecha_inicio", LocalDate.class),
                        rs.getObject("fecha_fin", LocalDate.class),
                        rs.getInt("cantidad_turnos"),
                        rs.getBoolean("consultorio_varia")
                ),
                java.time.LocalDate.now(java.time.ZoneId.of("America/Montevideo")),
                id
        );
        if (resultado.isEmpty()) {
            return Optional.empty();
        }

        PatronBase base = resultado.getFirst();
        List<TurnoSemanalResponse.NumeroSemanalResponse> numeros =
                jdbcTemplate.query(
                        """
                        SELECT numero, hora_inicio, hora_fin
                        FROM public.numero_semanal
                        WHERE id_turno_semanal = ?
                        ORDER BY numero
                        """,
                        (rs, rowNum) ->
                                new TurnoSemanalResponse.NumeroSemanalResponse(
                                        rs.getInt("numero"),
                                        rs.getObject(
                                                "hora_inicio",
                                                LocalTime.class
                                        ).toString(),
                                        rs.getObject(
                                                "hora_fin",
                                                LocalTime.class
                                        ).toString()
                                ),
                        id
                );
        return Optional.of(new TurnoSemanalResponse(
                base.id(),
                base.medico(),
                base.especialidad(),
                base.consultorio(),
                base.diaSemana(),
                base.fechaInicio(),
                base.fechaFin(),
                numeros,
                base.cantidadTurnos(),
                base.consultorioVariaPorFecha()
        ));
    }

    private FiltrosSql construirFiltros(FiltroTurnosDTO filtro) {
        List<String> condiciones = new ArrayList<>();
        List<Object> parametros = new ArrayList<>();
        if (filtro.medicoId() != null) {
            condiciones.add("ts.id_medico = ?");
            parametros.add(filtro.medicoId());
        }
        if (filtro.especialidadId() != null) {
            condiciones.add("ts.id_especialidad = ?");
            parametros.add(filtro.especialidadId());
        }
        if (filtro.diaSemana() != null) {
            condiciones.add("EXTRACT(ISODOW FROM t.fecha)::integer = ?");
            parametros.add(filtro.diaSemana());
        }
        if (filtro.fechaDesde() != null) {
            condiciones.add("t.fecha >= ?");
            parametros.add(filtro.fechaDesde());
        }
        if (filtro.fechaHasta() != null) {
            condiciones.add("t.fecha <= ?");
            parametros.add(filtro.fechaHasta());
        }
        if (filtro.estado() != null) {
            condiciones.add("t.estado = ?");
            parametros.add(filtro.estado());
        }
        String where = condiciones.isEmpty()
                ? ""
                : "WHERE " + String.join(" AND ", condiciones);
        return new FiltrosSql(where, parametros);
    }

    private String ordenSql(String orden, String sentido) {
        String direccion = sentido.equals("desc") ? "DESC" : "ASC";
        return switch (orden) {
            case "medico" -> "persona.apellido " + direccion
                    + ", persona.nombre " + direccion
                    + ", t.fecha " + direccion
                    + ", MIN(n.hora_inicio) " + direccion;
            case "especialidad" -> "e.nombre " + direccion
                    + ", t.fecha " + direccion
                    + ", MIN(n.hora_inicio) " + direccion;
            default -> "t.fecha " + direccion
                    + ", MIN(n.hora_inicio) " + direccion
                    + ", persona.apellido " + direccion
                    + ", persona.nombre " + direccion;
        };
    }

    private record FiltrosSql(String where, List<Object> parametros) {
    }

    private record PatronBase(
            Long id,
            TurnoSemanalResponse.MedicoRef medico,
            Especialidad especialidad,
            Consultorio consultorio,
            int diaSemana,
            LocalDate fechaInicio,
            LocalDate fechaFin,
            int cantidadTurnos,
            boolean consultorioVariaPorFecha
    ) {
    }
}
