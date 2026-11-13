package uy.edu.proyecto.backend.turno;

/**
 * RF-20: se modifica el consultorio en las fechas seleccionadas con turnoIds.
 * Si esas fechas tienen consultas AGENDADA, confirmarConConsultas exige
 * consentimiento expreso. Los otros datos del turno semanal no se modifican.
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
