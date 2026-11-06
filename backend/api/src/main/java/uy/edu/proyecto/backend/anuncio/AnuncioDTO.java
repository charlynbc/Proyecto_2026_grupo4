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
    public record Datos(String titulo, String resumen, String texto) { }
}
