package uy.edu.proyecto.backend.estadistica;

import uy.edu.proyecto.backend.especialidad.Especialidad;

public record EstadisticaEspecialidadDTO(
        Especialidad especialidad,
        long cantidadConsultas
) {
}
