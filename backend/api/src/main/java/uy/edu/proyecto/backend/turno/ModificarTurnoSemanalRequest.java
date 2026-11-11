package uy.edu.proyecto.backend.turno;

/**
 * RF-20: unico campo modificable de una configuracion semanal de turnos.
 * El medico, la especialidad, el dia de la semana y los horarios de los
 * numeros no se modifican: para cambiarlos se da de alta otro turno (RF-13).
 */
public record ModificarTurnoSemanalRequest(
        Long consultorioId,
        java.util.List<Long> turnoIds,
        Boolean confirmarConConsultas
) {
    // Compatibilidad con el contrato original y sus pruebas.
    public ModificarTurnoSemanalRequest(Long consultorioId) {
        this(consultorioId, null, false);
    }
}
