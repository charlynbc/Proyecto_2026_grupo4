package uy.edu.proyecto.backend.consultorio;

/** Fila del CSV de consultorios ya validada; error != null si se rechaza. */
public record FilaConsultorioCsv(
        int numero,
        String nombre,
        String ubicacion,
        String error
) {
    public boolean valida() {
        return error == null;
    }
}
