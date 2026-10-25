package uy.edu.proyecto.backend.pase;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class PaseRepository {

    private final JdbcTemplate jdbcTemplate;

    public PaseRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    // Mismas reglas que ConsultaRepository.bloquearPaseDisponible, sin bloqueo.
    public List<PaseDTO> listarDisponibles(Long socioId, LocalDate hoy) {
        return jdbcTemplate.query(
                """
                SELECT pase.id_pase, pase.emitido_en, pase.vence_el,
                       e.id_especialidad, e.nombre, e.requiere_pase
                FROM public.pase pase
                JOIN public.atencion atencion
                  ON atencion.id_atencion = pase.id_atencion
                JOIN public.consulta consulta
                  ON consulta.id_consulta = atencion.id_consulta
                JOIN public.especialidad e
                  ON e.id_especialidad = pase.id_especialidad_destino
                WHERE consulta.id_socio = ?
                  AND pase.vence_el >= ?
                  AND NOT EXISTS (
                      SELECT 1
                      FROM public.consulta usada
                      WHERE usada.id_pase = pase.id_pase
                        AND usada.estado NOT IN (
                            'CANCELADA_SOCIO',
                            'CANCELADA_INSTITUCION'
                        )
                  )
                ORDER BY pase.vence_el, pase.id_pase
                """,
                (rs, rowNum) -> new PaseDTO(
                        rs.getLong("id_pase"),
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        rs.getObject("emitido_en", OffsetDateTime.class),
                        rs.getObject("vence_el", LocalDate.class)
                ),
                socioId,
                hoy
        );
    }
}
