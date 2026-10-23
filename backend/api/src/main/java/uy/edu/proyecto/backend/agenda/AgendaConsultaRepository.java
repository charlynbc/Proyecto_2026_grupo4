package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class AgendaConsultaRepository {

    private static final String AGENDA_CTE = """
            WITH agenda_base AS (
                SELECT consulta.id_consulta,
                       socio.ci AS socio_ci,
                       socio_persona.nombre AS socio_nombre,
                       socio_persona.apellido AS socio_apellido,
                       semanal.id_medico,
                       medico_persona.nombre AS medico_nombre,
                       medico_persona.apellido AS medico_apellido,
                       especialidad.id_especialidad,
                       especialidad.nombre AS especialidad_nombre,
                       especialidad.requiere_pase,
                       turno.fecha,
                       numero.hora_inicio,
                       numero.hora_fin,
                       consultorio.id_consultorio,
                       consultorio.nombre AS consultorio_nombre,
                       consultorio.ubicacion AS consultorio_ubicacion,
                       CASE
                           WHEN consulta.estado = 'AGENDADA'
                                AND consulta.fecha_resultado IS NULL
                                AND turno.fecha < ? THEN
                               CASE
                                   WHEN aviso.id_aviso_llegada IS NOT NULL
                                       THEN 'NO_ATENDIDA'
                                   ELSE 'NO_ASISTIO'
                               END
                           ELSE consulta.estado
                       END AS estado,
                       aviso.registrada_en AS llegada_en
                FROM public.consulta consulta
                JOIN public.cuenta socio
                  ON socio.id_cuenta = consulta.id_socio
                JOIN public.persona socio_persona
                  ON socio_persona.ci = socio.ci
                JOIN public.numero numero
                  ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno
                  ON turno.id_turno = numero.id_turno
                JOIN public.turno_semanal semanal
                  ON semanal.id_turno_semanal = turno.id_turno_semanal
                JOIN public.cuenta medico
                  ON medico.id_cuenta = semanal.id_medico
                JOIN public.persona medico_persona
                  ON medico_persona.ci = medico.ci
                JOIN public.especialidad especialidad
                  ON especialidad.id_especialidad = semanal.id_especialidad
                JOIN public.consultorio consultorio
                  ON consultorio.id_consultorio = turno.id_consultorio
                LEFT JOIN public.aviso_llegada aviso
                  ON aviso.id_socio = consulta.id_socio
                 AND aviso.fecha = turno.fecha
            )
            """;

    private static final org.springframework.jdbc.core.RowMapper<AgendaOperativaDTO>
            ROW_MAPPER = (rs, rowNum) -> new AgendaOperativaDTO(
                    rs.getLong("id_consulta"),
                    new AgendaOperativaDTO.Socio(
                            rs.getString("socio_ci"),
                            rs.getString("socio_nombre"),
                            rs.getString("socio_apellido")
                    ),
                    new AgendaOperativaDTO.Medico(
                            rs.getLong("id_medico"),
                            rs.getString("medico_nombre"),
                            rs.getString("medico_apellido")
                    ),
                    new AgendaOperativaDTO.Especialidad(
                            rs.getLong("id_especialidad"),
                            rs.getString("especialidad_nombre"),
                            rs.getBoolean("requiere_pase")
                    ),
                    rs.getObject("fecha", LocalDate.class),
                    hora(rs.getObject("hora_inicio", LocalTime.class)),
                    hora(rs.getObject("hora_fin", LocalTime.class)),
                    new AgendaOperativaDTO.Consultorio(
                            rs.getLong("id_consultorio"),
                            rs.getString("consultorio_nombre"),
                            rs.getString("consultorio_ubicacion")
                    ),
                    rs.getString("estado"),
                    rs.getObject("llegada_en", OffsetDateTime.class)
            );

    private final JdbcTemplate jdbcTemplate;

    public AgendaConsultaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public AgendaOperativaPageResponse listar(
            FiltroAgendaDTO filtro,
            LocalDate hoy
    ) {
        List<Object> parametros = new ArrayList<>();
        String where = filtros(filtro, parametros);
        long total = Objects.requireNonNull(jdbcTemplate.queryForObject(
                AGENDA_CTE + "SELECT COUNT(*) FROM agenda_base" + where,
                Long.class,
                combinar(hoy, parametros)
        ), "La consulta de conteo debe devolver un total");

        List<Object> parametrosPagina = new ArrayList<>(parametros);
        parametrosPagina.add(filtro.size());
        parametrosPagina.add((long) filtro.page() * filtro.size());
        List<AgendaOperativaDTO> items = jdbcTemplate.query(
                AGENDA_CTE
                        + "SELECT * FROM agenda_base"
                        + where
                        + " ORDER BY " + ordenamiento(filtro)
                        + " LIMIT ? OFFSET ?",
                ROW_MAPPER,
                combinar(hoy, parametrosPagina)
        );
        return new AgendaOperativaPageResponse(
                items,
                filtro.page(),
                filtro.size(),
                total
        );
    }

    private String filtros(FiltroAgendaDTO filtro, List<Object> parametros) {
        List<String> condiciones = new ArrayList<>();
        if (filtro.ci() != null) {
            condiciones.add("socio_ci = ?");
            parametros.add(filtro.ci());
        }
        if (filtro.consultaId() != null) {
            condiciones.add("id_consulta = ?");
            parametros.add(filtro.consultaId());
        }
        if (filtro.fecha() != null) {
            condiciones.add("fecha = ?");
            parametros.add(filtro.fecha());
        }
        if (filtro.medicoId() != null) {
            condiciones.add("id_medico = ?");
            parametros.add(filtro.medicoId());
        }
        if (filtro.estado() != null) {
            condiciones.add("estado = ?");
            parametros.add(filtro.estado());
        }
        if (filtro.llegada() != null) {
            condiciones.add(filtro.llegada()
                    ? "llegada_en IS NOT NULL"
                    : "llegada_en IS NULL");
        }
        return condiciones.isEmpty()
                ? ""
                : " WHERE " + String.join(" AND ", condiciones);
    }

    private Object[] combinar(LocalDate hoy, List<Object> parametros) {
        List<Object> todos = new ArrayList<>();
        todos.add(hoy);
        todos.addAll(parametros);
        return todos.toArray();
    }

    private String ordenamiento(FiltroAgendaDTO filtro) {
        String direction = switch (filtro.sentido()) {
            case "asc" -> "ASC";
            case "desc" -> "DESC";
            default -> throw new IllegalArgumentException(
                    "sentido debe validarse antes de consultar el repositorio"
            );
        };
        return switch (filtro.orden()) {
            case "fechaHora" -> "fecha " + direction
                    + ", hora_inicio " + direction
                    + ", id_consulta ASC";
            case "horaLlegada" -> "llegada_en " + direction + " NULLS LAST"
                    + ", fecha " + direction
                    + ", hora_inicio " + direction
                    + ", id_consulta ASC";
            default -> throw new IllegalArgumentException(
                    "orden debe validarse antes de consultar el repositorio"
            );
        };
    }

    private static String hora(LocalTime hora) {
        return hora == null ? null : hora.toString();
    }
}
