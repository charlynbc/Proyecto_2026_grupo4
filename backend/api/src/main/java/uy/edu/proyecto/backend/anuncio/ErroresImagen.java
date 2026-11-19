package uy.edu.proyecto.backend.anuncio;

/** Codigo y mensaje del error de una imagen demasiado grande, para que la validacion y el limite de multipart digan lo mismo. */
public final class ErroresImagen {
    public static final String CODIGO = "IMAGEN_INVALIDA";
    public static final String TAMANO = "Cada imagen admite hasta 5 MB";

    private ErroresImagen() { }
}
