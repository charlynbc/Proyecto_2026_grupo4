package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class HistoriaClinicaRepository {

    private final JdbcTemplate jdbcTemplate;

    public HistoriaClinicaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<HistoriaClinicaDTO> listar(
            Long socioId,
            LocalDate fechaDesde,
            LocalDate fechaHasta,
            Long especialidadId,
            Long medicoId,
            String texto,
            String orden,
            String sentido
    ) {
        StringBuilder sql = new StringBuilder(
                """
                SELECT a.id_atencion,
                       a.registrada_en::date AS fecha_atencion,
                       medico.id_cuenta AS medico_id,
                       medico_persona.nombre AS medico_nombre,
                       medico_persona.apellido AS medico_apellido,
                       especialidad.id_especialidad,
                       especialidad.nombre AS especialidad_nombre,
                       especialidad.requiere_pase,
                       a.afeccion,
                       a.tratamiento,
                       a.observaciones
                FROM public.atencion a
                JOIN public.consulta consulta ON consulta.id_consulta = a.id_consulta
                JOIN public.numero numero ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno ON turno.id_turno = numero.id_turno
                JOIN public.turno_semanal semanal ON semanal.id_turno_semanal = turno.id_turno_semanal
                JOIN public.cuenta medico ON medico.id_cuenta = a.id_medico
                JOIN public.persona medico_persona ON medico_persona.ci = medico.ci
                JOIN public.especialidad especialidad ON especialidad.id_especialidad = semanal.id_especialidad
                WHERE consulta.id_socio = ?
                """
        );

        List<Object> parametros = new ArrayList<>();
        parametros.add(socioId);

        if (fechaDesde != null) {
            sql.append(" AND a.registrada_en::date >= ?");
            parametros.add(fechaDesde);
        }
        if (fechaHasta != null) {
            sql.append(" AND a.registrada_en::date <= ?");
            parametros.add(fechaHasta);
        }
        if (especialidadId != null) {
            sql.append(" AND especialidad.id_especialidad = ?");
            parametros.add(especialidadId);
        }
        if (medicoId != null) {
            sql.append(" AND medico.id_cuenta = ?");
            parametros.add(medicoId);
        }
        if (texto != null && !texto.isBlank()) {
            sql.append(" AND LOWER(COALESCE(a.tratamiento, '')) LIKE LOWER(?)");
            parametros.add("%" + texto.trim() + "%");
        }

        String campoOrden = "fecha_atencion".equals(orden)
                ? "a.registrada_en::date"
                : "especialidad.nombre";
        sql.append(" ORDER BY ")
                .append(campoOrden)
                .append(" ")
                .append(sentido)
                .append(", a.id_atencion ")
                .append(sentido);

        List<HistoriaClinicaDTO> items = jdbcTemplate.query(
                sql.toString(),
                (rs, rowNum) -> new HistoriaClinicaDTO(
                        rs.getLong("id_atencion"),
                        rs.getObject("fecha_atencion", LocalDate.class),
                        rs.getLong("medico_id"),
                        rs.getString("medico_nombre"),
                        rs.getString("medico_apellido"),
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("especialidad_nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        rs.getString("afeccion"),
                        rs.getString("tratamiento"),
                        rs.getString("observaciones"),
                        List.of()
                ),
                parametros.toArray()
        );

        if (items.isEmpty()) {
            return List.of();
        }

        List<Long> ids = items.stream().map(HistoriaClinicaDTO::idAtencion).toList();
        Map<Long, List<HistoriaClinicaDTO.PaseClinicaDTO>> pases = listarPasesPorAtencion(ids);

        return items.stream()
                .map(item -> new HistoriaClinicaDTO(
                        item.idAtencion(),
                        item.fechaAtencion(),
                        item.medicoId(),
                        item.medicoNombre(),
                        item.medicoApellido(),
                        item.especialidad(),
                        item.afeccion(),
                        item.tratamiento(),
                        item.observaciones(),
                        pases.getOrDefault(item.idAtencion(), List.of())
                ))
                .collect(Collectors.toList());
    }

    public HistoriaClinicaDTO obtenerDetalle(Long socioId, Long idAtencion) {
        List<HistoriaClinicaDTO> items = jdbcTemplate.query(
                """
                SELECT a.id_atencion,
                       a.registrada_en::date AS fecha_atencion,
                       medico.id_cuenta AS medico_id,
                       medico_persona.nombre AS medico_nombre,
                       medico_persona.apellido AS medico_apellido,
                       especialidad.id_especialidad,
                       especialidad.nombre AS especialidad_nombre,
                       especialidad.requiere_pase,
                       a.afeccion,
                       a.tratamiento,
                       a.observaciones
                FROM public.atencion a
                JOIN public.consulta consulta ON consulta.id_consulta = a.id_consulta
                JOIN public.numero numero ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno ON turno.id_turno = numero.id_turno
                JOIN public.turno_semanal semanal ON semanal.id_turno_semanal = turno.id_turno_semanal
                JOIN public.cuenta medico ON medico.id_cuenta = a.id_medico
                JOIN public.persona medico_persona ON medico_persona.ci = medico.ci
                JOIN public.especialidad especialidad ON especialidad.id_especialidad = semanal.id_especialidad
                WHERE consulta.id_socio = ?
                  AND a.id_atencion = ?
                """,
                (rs, rowNum) -> new HistoriaClinicaDTO(
                        rs.getLong("id_atencion"),
                        rs.getObject("fecha_atencion", LocalDate.class),
                        rs.getLong("medico_id"),
                        rs.getString("medico_nombre"),
                        rs.getString("medico_apellido"),
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("especialidad_nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        rs.getString("afeccion"),
                        rs.getString("tratamiento"),
                        rs.getString("observaciones"),
                        List.of()
                ),
                socioId,
                idAtencion
        );

        if (items.isEmpty()) {
            return null;
        }

        HistoriaClinicaDTO item = items.getFirst();
        List<HistoriaClinicaDTO.PaseClinicaDTO> pases = listarPasesPorAtencion(List.of(item.idAtencion()))
                .getOrDefault(item.idAtencion(), List.of());
        return new HistoriaClinicaDTO(
                item.idAtencion(),
                item.fechaAtencion(),
                item.medicoId(),
                item.medicoNombre(),
                item.medicoApellido(),
                item.especialidad(),
                item.afeccion(),
                item.tratamiento(),
                item.observaciones(),
                pases
        );
    }

    private Map<Long, List<HistoriaClinicaDTO.PaseClinicaDTO>> listarPasesPorAtencion(List<Long> ids) {
        if (ids.isEmpty()) {
            return Map.of();
        }

        String placeholders = ids.stream().map(ignored -> "?").collect(Collectors.joining(", "));
        String sql = """
                SELECT p.id_atencion,
                       p.id_pase,
                       p.emitido_en,
                       p.vence_el,
                       e.id_especialidad,
                       e.nombre AS especialidad_nombre,
                       e.requiere_pase
                FROM public.pase p
                JOIN public.especialidad e ON e.id_especialidad = p.id_especialidad_destino
                WHERE p.id_atencion IN (%s)
                ORDER BY p.vence_el DESC, p.emitido_en DESC
                """.formatted(placeholders);

        Map<Long, List<HistoriaClinicaDTO.PaseClinicaDTO>> pasesPorAtencion = new LinkedHashMap<>();
        jdbcTemplate.query(
                sql,
                (rs, rowNum) -> {
                    Long idAtencion = rs.getLong("id_atencion");
                    HistoriaClinicaDTO.PaseClinicaDTO pase = new HistoriaClinicaDTO.PaseClinicaDTO(
                            rs.getLong("id_pase"),
                            new Especialidad(
                                    rs.getLong("id_especialidad"),
                                    rs.getString("especialidad_nombre"),
                                    rs.getBoolean("requiere_pase")
                            ),
                            rs.getObject("emitido_en", OffsetDateTime.class),
                            rs.getObject("vence_el", LocalDate.class)
                    );
                    pasesPorAtencion.computeIfAbsent(idAtencion, ignored -> new ArrayList<>()).add(pase);
                    return null;
                },
                ids.toArray()
        );

        return pasesPorAtencion;
    }
}
