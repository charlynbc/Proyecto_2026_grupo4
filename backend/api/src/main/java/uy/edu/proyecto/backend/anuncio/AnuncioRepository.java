package uy.edu.proyecto.backend.anuncio;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class AnuncioRepository {
    record Fila(long id, String titulo, String resumen, String texto, OffsetDateTime publicadoEn) { }
    record ImagenFila(long id, int orden, String referencia) { }

    private final JdbcTemplate jdbc;

    public AnuncioRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    long crear(long administradorId, AnuncioDTO.Datos datos) {
        return jdbc.queryForObject("""
                INSERT INTO public.anuncio (id_administrador, titulo, resumen, texto)
                VALUES (?, ?, ?, ?) RETURNING id_anuncio
                """, Long.class, administradorId, datos.titulo(), datos.resumen(), datos.texto());
    }

    void agregarImagen(long anuncioId, String referencia, int orden) {
        jdbc.update("""
                INSERT INTO public.imagen_anuncio (id_anuncio, referencia_archivo, orden)
                VALUES (?, ?, ?)
                """, anuncioId, referencia, orden);
    }

    List<Fila> listar(int page, int size) {
        return jdbc.query("""
                SELECT id_anuncio, titulo, resumen, texto, publicado_en
                FROM public.anuncio
                ORDER BY publicado_en DESC, id_anuncio DESC
                LIMIT ? OFFSET ?
                """, (rs, row) -> fila(rs), size, (long) page * size);
    }

    long total() {
        return jdbc.queryForObject("SELECT count(*) FROM public.anuncio", Long.class);
    }

    Fila buscar(long id) {
        return jdbc.query("""
                SELECT id_anuncio, titulo, resumen, texto, publicado_en
                FROM public.anuncio WHERE id_anuncio = ?
                """, (rs, row) -> fila(rs), id).stream().findFirst().orElse(null);
    }

    List<ImagenFila> imagenes(long anuncioId) {
        return jdbc.query("""
                SELECT id_imagen, orden, referencia_archivo
                FROM public.imagen_anuncio WHERE id_anuncio = ?
                ORDER BY orden, id_imagen
                """, (rs, row) -> new ImagenFila(rs.getLong("id_imagen"),
                rs.getInt("orden"), rs.getString("referencia_archivo")), anuncioId);
    }

    private static Fila fila(ResultSet rs) throws SQLException {
        return new Fila(rs.getLong("id_anuncio"), rs.getString("titulo"),
                rs.getString("resumen"), rs.getString("texto"),
                rs.getObject("publicado_en", OffsetDateTime.class));
    }
}
