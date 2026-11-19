package uy.edu.proyecto.backend.turno;

/**
 * RF-20: se modifica el consultorio en las fechas seleccionadas con turnoIds.
 * Si esas fechas tienen consultas AGENDADA, confirmarConConsultas exige
 * consentimiento expreso. Los otros datos del turno semanal no se modifican.
 *
 * consultasAgendadasVistas es el total de consultas AGENDADA que el
 * funcionario vio en la vista previa para las fechas elegidas. Solo cuenta
 * junto con confirmarConConsultas en true: si el total real ya no coincide,
 * la confirmacion quedo vieja y el cambio se rechaza.
 */
public record ModificarTurnoSemanalRequest(
        Long consultorioId,
        java.util.List<Long> turnoIds,
        Boolean confirmarConConsultas,
        Integer consultasAgendadasVistas
) {
    // Compatibilidad con el contrato original y sus pruebas.
    public ModificarTurnoSemanalRequest(Long consultorioId) {
        this(consultorioId, null, false, null);
    }

    // Compatibilidad con la ampliacion previa, sin el total visto.
    public ModificarTurnoSemanalRequest(
            Long consultorioId,
            java.util.List<Long> turnoIds,
            Boolean confirmarConConsultas
    ) {
        this(consultorioId, turnoIds, confirmarConConsultas, null);
    }
}
