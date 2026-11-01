package uy.edu.proyecto.backend.pase;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.atencion.AtencionMedicaDTO;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class PaseMedicoRepository {

    // Un pase está utilizado si alguna consulta lo usa sin estar cancelada; la cancelación
    // lo devuelve (RF-09) y una reutilización posterior vuelve a marcarlo. El EXISTS sobre
    // todas las consultas asociadas evita duplicar el pase en el resultado.
    private static final String USO_NO_CANCELADO = """
            EXISTS (
                SELECT 1
                FROM public.consulta uso
                WHERE uso.id_pase = pase.id_pase
                  AND uso.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
            )
            """;

    private final JdbcTemplate jdbcTemplate;

    public PaseMedicoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<PaseEmitidoDTO> listarEmitidos(
            Long medicoId,
            String situacion,
            String orden,
            String sentido,
            LocalDate hoy
    ) {
        StringBuilder sql = new StringBuilder("""
                SELECT pase.id_pase, pase.emitido_en, pase.vence_el,
                       e.id_especialidad, e.nombre AS especialidad_nombre, e.requiere_pase,
                       socio.id_cuenta AS paciente_id, socio.ci AS paciente_ci,
                       paciente.nombre AS paciente_nombre,
                       paciente.apellido AS paciente_apellido,
                """ + USO_NO_CANCELADO + " AS utilizado "
                + """
                FROM public.pase pase
                JOIN public.atencion atencion
                  ON atencion.id_atencion = pase.id_atencion
                JOIN public.consulta consulta
                  ON consulta.id_consulta = atencion.id_consulta
                JOIN public.cuenta socio ON socio.id_cuenta = consulta.id_socio
                JOIN public.persona paciente ON paciente.ci = socio.ci
                JOIN public.especialidad e
                  ON e.id_especialidad = pase.id_especialidad_destino
                WHERE atencion.id_medico = ?
                """);

        List<Object> parametros = new ArrayList<>();
        parametros.add(medicoId);

        // La situación se calcula al consultar: no hay columna de estado en pase.
        if ("UTILIZADO".equals(situacion)) {
            sql.append(" AND ").append(USO_NO_CANCELADO);
        } else if ("VENCIDO".equals(situacion)) {
            sql.append(" AND NOT ").append(USO_NO_CANCELADO)
                    .append(" AND pase.vence_el < ?");
            parametros.add(hoy);
        } else if ("DISPONIBLE".equals(situacion)) {
            sql.append(" AND NOT ").append(USO_NO_CANCELADO)
                    .append(" AND pase.vence_el >= ?");
            parametros.add(hoy);
        }

        // Solo valores de lista blanca validados en el servicio.
        String direccion = "desc".equals(sentido) ? "DESC" : "ASC";
        if ("emision".equals(orden)) {
            sql.append(" ORDER BY pase.emitido_en ").append(direccion)
                    .append(", pase.id_pase ").append(direccion);
        } else {
            sql.append(" ORDER BY pase.vence_el ").append(direccion)
                    .append(", pase.id_pase ").append(direccion);
        }

        return jdbcTemplate.query(
                sql.toString(),
                (rs, rowNum) -> {
                    boolean utilizado = rs.getBoolean("utilizado");
                    LocalDate venceEl = rs.getObject("vence_el", LocalDate.class);
                    String calculada = utilizado
                            ? "UTILIZADO"
                            : (venceEl.isBefore(hoy) ? "VENCIDO" : "DISPONIBLE");
                    return new PaseEmitidoDTO(
                            rs.getLong("id_pase"),
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
                            rs.getObject("emitido_en", OffsetDateTime.class),
                            venceEl,
                            calculada
                    );
                },
                parametros.toArray()
        );
    }
}
