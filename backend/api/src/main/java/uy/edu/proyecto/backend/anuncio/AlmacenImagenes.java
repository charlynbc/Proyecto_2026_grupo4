package uy.edu.proyecto.backend.anuncio;

public interface AlmacenImagenes {
    void guardar(String referencia, byte[] contenido, String tipo);
    String enlaceTemporal(String referencia);
    void borrar(String referencia);
}
