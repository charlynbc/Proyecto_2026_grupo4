package uy.edu.proyecto.backend.especialidad;

/**
 * Correccion administrativa de una especialidad (RF-38). Ambos campos son
 * opcionales, pero al menos uno debe venir; el cambio de requierePase rige
 * para las consultas que se agenden desde ese momento (RF-29).
 */
public record CorregirEspecialidadRequest(
        String nombre,
        Boolean requierePase
) {
}
