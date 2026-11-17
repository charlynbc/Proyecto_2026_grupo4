package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.List;

public final class AnuncioDTO {
    private AnuncioDTO() { }

    public record Imagen(long id, int orden, String url) { }
    public record Tarjeta(long id, String titulo, String resumen,
                          OffsetDateTime publicadoEn, Imagen imagenPortada) { }
    public record Detalle(long id, String titulo, String resumen, String texto,
                          OffsetDateTime publicadoEn, List<Imagen> imagenes) { }
    public record Pagina(List<Tarjeta> items, int page, int size, long total) { }
    public record Datos(String titulo, String resumen, String texto, OffsetDateTime vigenteDesde, OffsetDateTime vigenteHasta) {
        public Datos(String titulo, String resumen, String texto) { this(titulo, resumen, texto, null, null); }
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
