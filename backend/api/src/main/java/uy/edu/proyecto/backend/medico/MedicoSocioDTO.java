package uy.edu.proyecto.backend.medico;

import java.util.List;

/** Proyección mínima del selector de médicos para el socio (RF-08). */
public record MedicoSocioDTO(
        Long id,
        String nombre,
        String apellido,
        List<EspecialidadSocioDTO> especialidades
) {
    public record EspecialidadSocioDTO(Long id, String nombre) {
    }

    public static MedicoSocioDTO desde(MedicoDTO medico) {
        return new MedicoSocioDTO(
                medico.id(),
                medico.nombre(),
                medico.apellido(),
                medico.especialidades().stream()
                        .map(e -> new EspecialidadSocioDTO(e.id(), e.nombre()))
                        .toList()
        );
    }
}
