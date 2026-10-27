package uy.edu.proyecto.backend.medico;

import java.util.List;

import uy.edu.proyecto.backend.especialidad.Especialidad;

public record MedicoDTO(
        Long id,
        String nombre,
        String apellido,
        List<Especialidad> especialidades
) {
}
