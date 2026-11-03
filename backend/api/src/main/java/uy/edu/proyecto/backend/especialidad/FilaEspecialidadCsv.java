package uy.edu.proyecto.backend.especialidad;

/** Fila del CSV de especialidades ya validada; error != null si se rechaza. */
public record FilaEspecialidadCsv(
        int numero,
        String nombre,
        Boolean requierePase,
        String error
) {
    public boolean valida() {
        return error == null;
    }
}
