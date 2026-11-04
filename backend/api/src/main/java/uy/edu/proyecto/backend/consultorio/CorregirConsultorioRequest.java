package uy.edu.proyecto.backend.consultorio;

/**
 * Correccion administrativa de un consultorio (RF-38). Ambos campos son
 * opcionales, pero al menos uno debe venir. Las relaciones con turnos y
 * consultas se conservan (referencian al consultorio por id).
 */
public record CorregirConsultorioRequest(
        String nombre,
        String ubicacion
) {
}
