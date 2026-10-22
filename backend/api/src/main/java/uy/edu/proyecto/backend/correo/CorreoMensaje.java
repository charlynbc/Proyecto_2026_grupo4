package uy.edu.proyecto.backend.correo;

public record CorreoMensaje(
        String para,
        String asunto,
        String texto
) {

    // El texto puede contener enlaces de un solo uso: nunca se imprime.
    @Override
    public String toString() {
        return "CorreoMensaje[asunto=" + asunto + "]";
    }
}
