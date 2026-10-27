package uy.edu.proyecto.backend.medico;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class MedicoRepository {

    private final JdbcTemplate jdbcTemplate;

    public MedicoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<MedicoDTO> listar(Long especialidadId) {
        StringBuilder sql = new StringBuilder(
                """
                SELECT c.id_cuenta AS id_medico,
                       p.nombre,
                       p.apellido,
                       e.id_especialidad,
                       e.nombre AS especialidad_nombre,
                       e.requiere_pase
                FROM public.cuenta c
                JOIN public.persona p ON p.ci = c.ci
                JOIN public.medico_especialidad me ON me.id_medico = c.id_cuenta
                JOIN public.especialidad e ON e.id_especialidad = me.id_especialidad
                WHERE c.rol = 'MEDICO'
                  AND c.habilitada = TRUE
                """
        );

        List<Object> parametros = new ArrayList<>();
        if (especialidadId != null) {
            sql.append(
                    """
                     AND EXISTS (
                         SELECT 1
                         FROM public.medico_especialidad filtro
                         WHERE filtro.id_medico = c.id_cuenta
                           AND filtro.id_especialidad = ?
                     )
                    """
            );
            parametros.add(especialidadId);
        }

        sql.append(" ORDER BY p.apellido ASC, p.nombre ASC, e.nombre ASC");

        Map<Long, MedicoDTO> porMedico = new LinkedHashMap<>();
        jdbcTemplate.query(
                sql.toString(),
                (rs, rowNum) -> {
                    Long idMedico = rs.getLong("id_medico");
                    MedicoDTO medico = porMedico.get(idMedico);
                    if (medico == null) {
                        medico = new MedicoDTO(
                                idMedico,
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                new ArrayList<>()
                        );
                        porMedico.put(idMedico, medico);
                    }

                    List<Especialidad> especialidades = new ArrayList<>(medico.especialidades());
                    especialidades.add(new Especialidad(
                            rs.getLong("id_especialidad"),
                            rs.getString("especialidad_nombre"),
                            rs.getBoolean("requiere_pase")
                    ));
                    porMedico.put(
                            idMedico,
                            new MedicoDTO(
                                    medico.id(),
                                    medico.nombre(),
                                    medico.apellido(),
                                    especialidades
                            )
                    );
                    return null;
                },
                parametros.toArray()
        );

        return new ArrayList<>(porMedico.values());
    }
}
