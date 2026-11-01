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
public class AtencionMedicoRepository {

    // La fecha de atención es el día calendario de Montevideo, independiente de la zona de la sesión.
    private static final String FECHA_ATENCION =
            "(a.registrada_en AT TIME ZONE 'America/Montevideo')::date";

    // Solo atenciones registradas por el médico autenticado (atencion.id_medico), nunca
    // las que haya registrado otra persona sobre turnos suyos.
    private static final String DESDE_ATENCION_PROPIA = """
            FROM public.atencion a
            JOIN public.consulta consulta ON consulta.id_consulta = a.id_consulta
            JOIN public.cuenta socio ON socio.id_cuenta = consulta.id_socio
            JOIN public.persona paciente ON paciente.ci = socio.ci
            JOIN public.numero numero ON numero.id_numero = consulta.id_numero
            JOIN public.turno turno ON turno.id_turno = numero.id_turno
            JOIN public.turno_semanal semanal
              ON semanal.id_turno_semanal = turno.id_turno_semanal
            JOIN public.especialidad especialidad
              ON especialidad.id_especialidad = semanal.id_especialidad
            """;

    private static final String COLUMNAS = """
            SELECT a.id_atencion,
            """ + FECHA_ATENCION + """
             AS fecha_atencion,
                   socio.id_cuenta AS paciente_id,
                   socio.ci AS paciente_ci,
                   paciente.nombre AS paciente_nombre,
                   paciente.apellido AS paciente_apellido,
                   especialidad.id_especialidad,
                   especialidad.nombre AS especialidad_nombre,
                   especialidad.requiere_pase,
                   a.afeccion,
                   a.tratamiento,
                   a.observaciones
            """;

    private final JdbcTemplate jdbcTemplate;

    public AtencionMedicoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    private static String escaparLike(String texto) {
        return texto.replace("!", "!!").replace("%", "!%").replace("_", "!_");
    }

    public List<AtencionMedicaDTO> listar(
            Long medicoId,
            LocalDate fechaDesde,
            LocalDate fechaHasta,
            String paciente,
            Long especialidadId,
            String orden,
            String sentido
    ) {
        StringBuilder sql = new StringBuilder(COLUMNAS + DESDE_ATENCION_PROPIA
                + " WHERE a.id_medico = ? AND " + FECHA_ATENCION + " >= ?"
                + " AND " + FECHA_ATENCION + " <= ?");
        List<Object> parametros = new ArrayList<>();
        parametros.add(medicoId);
        parametros.add(fechaDesde);
        parametros.add(fechaHasta);

        if (paciente != null) {
            String textoBusqueda = "%" + escaparLike(paciente) + "%";
            sql.append(" AND (LOWER(socio.ci) LIKE LOWER(?) ESCAPE '!'"
                    + " OR LOWER(paciente.apellido) LIKE LOWER(?) ESCAPE '!')");
            parametros.add(textoBusqueda);
            parametros.add(textoBusqueda);
        }
        if (especialidadId != null) {
            sql.append(" AND especialidad.id_especialidad = ?");
            parametros.add(especialidadId);
        }

        // Solo valores de lista blanca validados en el servicio.
        String direccion = "desc".equals(sentido) ? "DESC" : "ASC";
        if ("apellido".equals(orden)) {
            sql.append(" ORDER BY paciente.apellido ").append(direccion)
                    .append(", ").append(FECHA_ATENCION).append(" DESC, a.id_atencion ASC");
        } else {
            sql.append(" ORDER BY ").append(FECHA_ATENCION).append(" ").append(direccion)
                    .append(", a.id_atencion ").append(direccion);
        }

        List<AtencionMedicaDTO> items = jdbcTemplate.query(
                sql.toString(),
                (rs, rowNum) -> mapear(rs),
                parametros.toArray()
        );
        return conPases(items);
    }

    public AtencionMedicaDTO obtenerDetallePropio(Long medicoId, Long idAtencion) {
        List<AtencionMedicaDTO> items = jdbcTemplate.query(
                COLUMNAS + DESDE_ATENCION_PROPIA
                        + " WHERE a.id_medico = ? AND a.id_atencion = ?",
                (rs, rowNum) -> mapear(rs),
                medicoId,
                idAtencion
        );
        if (items.isEmpty()) {
            return null;
        }
        return conPases(items).getFirst();
    }

    private AtencionMedicaDTO mapear(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new AtencionMedicaDTO(
                rs.getLong("id_atencion"),
                rs.getObject("fecha_atencion", LocalDate.class),
                new AtencionMedicaDTO.PacienteRef(
                        rs.getLong("paciente_id"),
                        rs.getString("paciente_ci"),
                        rs.getString("paciente_nombre"),
                        rs.getString("paciente_apellido")
                ),
                new Especialidad(
                        rs.getLong("id_especialidad"),
                        rs.getString("especialidad_nombre"),
                        rs.getBoolean("requiere_pase")
                ),
                rs.getString("afeccion"),
                rs.getString("tratamiento"),
                rs.getString("observaciones"),
                List.of()
        );
    }

    private List<AtencionMedicaDTO> conPases(List<AtencionMedicaDTO> items) {
        if (items.isEmpty()) {
            return List.of();
        }
        List<Long> ids = items.stream().map(AtencionMedicaDTO::idAtencion).toList();
        Map<Long, List<HistoriaClinicaDTO.PaseClinicaDTO>> pases = listarPasesPorAtencion(ids);
        return items.stream()
                .map(item -> new AtencionMedicaDTO(
                        item.idAtencion(),
                        item.fechaAtencion(),
                        item.paciente(),
                        item.especialidad(),
                        item.afeccion(),
                        item.tratamiento(),
                        item.observaciones(),
                        pases.getOrDefault(item.idAtencion(), List.of())
                ))
                .collect(Collectors.toList());
    }

    private Map<Long, List<HistoriaClinicaDTO.PaseClinicaDTO>> listarPasesPorAtencion(
            List<Long> ids) {
        String placeholders = ids.stream()
                .map(ignored -> "?")
                .collect(Collectors.joining(", "));
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

        Map<Long, List<HistoriaClinicaDTO.PaseClinicaDTO>> pasesPorAtencion =
                new LinkedHashMap<>();
        jdbcTemplate.query(
                sql,
                (rs, rowNum) -> {
                    Long idAtencion = rs.getLong("id_atencion");
                    HistoriaClinicaDTO.PaseClinicaDTO pase =
                            new HistoriaClinicaDTO.PaseClinicaDTO(
                                    rs.getLong("id_pase"),
                                    new Especialidad(
                                            rs.getLong("id_especialidad"),
                                            rs.getString("especialidad_nombre"),
                                            rs.getBoolean("requiere_pase")
                                    ),
                                    rs.getObject("emitido_en", OffsetDateTime.class),
                                    rs.getObject("vence_el", LocalDate.class)
                            );
                    pasesPorAtencion.computeIfAbsent(idAtencion, ignored -> new ArrayList<>())
                            .add(pase);
                    return null;
                },
                ids.toArray()
        );
        return pasesPorAtencion;
    }
}
