package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.List;

public final class AnuncioDTO {
    private AnuncioDTO() { }

    /**
     * Una imagen de la novedad. {@code url} es el original firmado; {@code urlMiniatura} es la miniatura firmada y
     * es null (siempre presente en el JSON) si la novedad no tiene miniatura o no se pudo firmar.
     */
    public record Imagen(long id, int orden, String url, String urlMiniatura) {
        public Imagen(long id, int orden, String url) { this(id, orden, url, null); }
    }
    public record Tarjeta(long id, String titulo, String resumen,
                          OffsetDateTime publicadoEn, Imagen imagenPortada) { }
    public record Detalle(long id, String titulo, String resumen, String texto,
                          OffsetDateTime publicadoEn, List<Imagen> imagenes) { }
    public record Pagina(List<Tarjeta> items, int page, int size, long total) { }
    public record Datos(String titulo, String resumen, String texto, OffsetDateTime vigenteDesde, OffsetDateTime vigenteHasta) {
        public Datos(String titulo, String resumen, String texto) { this(titulo, resumen, texto, null, null); }
    }
    /** Una entrada de la lista final de imagenes: o una existente (id) o una nueva (nombre de la parte de archivo). */
    public record ImagenEdicion(Long id, String archivo) { }
    /** Edicion de una novedad; con imagenes en null las imagenes no se tocan, con una lista es la lista final en orden. */
    public record Edicion(String titulo, String resumen, String texto, List<ImagenEdicion> imagenes) {
        public Edicion(String titulo, String resumen, String texto) { this(titulo, resumen, texto, null); }
    }
    public record Vigencia(OffsetDateTime vigenteDesde, OffsetDateTime vigenteHasta) { }
    public record Administracion(long id, String titulo, OffsetDateTime publicadoEn, OffsetDateTime vigenteDesde,
                                  OffsetDateTime vigenteHasta, String estado, Integer posicion) { }
    public record DetalleAdministracion(long id, String titulo, String resumen, String texto,
                                        OffsetDateTime publicadoEn, OffsetDateTime vigenteDesde,
                                        OffsetDateTime vigenteHasta, String estado, Integer posicion,
                                        List<Imagen> imagenes) { }
    public record Posicion(int posicion, long anuncioId) { }
    public record Carrusel(List<Posicion> posiciones) { }

}
