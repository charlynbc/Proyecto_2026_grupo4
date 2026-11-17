package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CarteleraRepository {
    private final JdbcTemplate jdbc;
    public CarteleraRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    void bloquearCambios() { jdbc.queryForObject("SELECT pg_advisory_xact_lock(20261114, 1) IS NULL", Boolean.class); }
    List<AnuncioDTO.Posicion> posiciones() {
        return jdbc.query("SELECT posicion_carrusel,id_anuncio FROM public.anuncio WHERE posicion_carrusel IS NOT NULL ORDER BY posicion_carrusel",
                (rs, n) -> new AnuncioDTO.Posicion(rs.getInt(1), rs.getLong(2)));
    }
    boolean existe(long id) { return Boolean.TRUE.equals(jdbc.queryForObject(
            "SELECT EXISTS(SELECT 1 FROM public.anuncio WHERE id_anuncio=?)", Boolean.class, id)); }
    void reemplazar(List<AnuncioDTO.Posicion> posiciones) {
        jdbc.update("UPDATE public.anuncio SET posicion_carrusel=NULL WHERE posicion_carrusel IS NOT NULL");
        for (var p : posiciones) jdbc.update("UPDATE public.anuncio SET posicion_carrusel=? WHERE id_anuncio=?", p.posicion(), p.anuncioId());
    }
    private static final String ADMINISTRACION = """
            SELECT a.id_anuncio,a.titulo,a.publicado_en,a.vigente_desde,a.vigente_hasta,a.posicion_carrusel,
              CASE WHEN a.vigente_desde > CURRENT_TIMESTAMP THEN 'PROGRAMADO'
                   WHEN a.vigente_hasta <= CURRENT_TIMESTAMP THEN 'VENCIDO' ELSE 'VIGENTE' END estado
            FROM public.anuncio a
            """;
    private static AnuncioDTO.Administracion administracion(java.sql.ResultSet rs, int n) throws java.sql.SQLException {
        return new AnuncioDTO.Administracion(rs.getLong(1),rs.getString(2),
                rs.getObject(3,OffsetDateTime.class),rs.getObject(4,OffsetDateTime.class),
                rs.getObject(5,OffsetDateTime.class),rs.getString("estado"),rs.getObject(6, Integer.class));
    }
    List<AnuncioDTO.Administracion> listar() {
        return jdbc.query(ADMINISTRACION + "ORDER BY a.publicado_en DESC,a.id_anuncio DESC",
                CarteleraRepository::administracion);
    }
    /** Una fila de administracion (con estado y posicion), o null si no existe. */
    AnuncioDTO.Administracion administracion(long id) {
        return jdbc.query(ADMINISTRACION + "WHERE a.id_anuncio=?", CarteleraRepository::administracion, id)
                .stream().findFirst().orElse(null);
    }
    void actualizarTexto(long id, String titulo, String resumen, String texto) {
        jdbc.update("UPDATE public.anuncio SET titulo=?, resumen=?, texto=? WHERE id_anuncio=?",titulo,resumen,texto,id);
    }
    int cantidadImagenes(long id) {
        return jdbc.queryForObject("SELECT count(*) FROM public.imagen_anuncio WHERE id_anuncio=?",Integer.class,id);
    }
    int vigencia(long id, AnuncioDTO.Vigencia v) {
        return jdbc.update("UPDATE public.anuncio SET vigente_desde=?, vigente_hasta=? WHERE id_anuncio=?",v.vigenteDesde(),v.vigenteHasta(),id);
    }
    OffsetDateTime publicadoEn(long id) {
        return jdbc.query("SELECT publicado_en FROM public.anuncio WHERE id_anuncio=? FOR UPDATE",
                (rs,n) -> rs.getObject(1,OffsetDateTime.class),id).stream().findFirst().orElse(null);
    }
    List<Long> visibles() {
        return jdbc.queryForList("""
                SELECT a.id_anuncio FROM public.anuncio a
                WHERE a.posicion_carrusel IS NOT NULL AND (a.vigente_desde IS NULL OR a.vigente_desde <= CURRENT_TIMESTAMP)
                  AND (a.vigente_hasta IS NULL OR CURRENT_TIMESTAMP < a.vigente_hasta)
                ORDER BY a.posicion_carrusel
                """,Long.class);
    }
    boolean eliminar(long id) {
        var ids = jdbc.queryForList("SELECT id_anuncio FROM public.anuncio WHERE id_anuncio=? FOR UPDATE",Long.class,id);
        if (ids.isEmpty()) return false;
        jdbc.update("INSERT INTO public.anuncio_archivo_pendiente_borrado(referencia_archivo) SELECT referencia_archivo FROM public.imagen_anuncio WHERE id_anuncio=? ON CONFLICT (referencia_archivo) DO NOTHING",id);
        jdbc.update("DELETE FROM public.imagen_anuncio WHERE id_anuncio=?",id);
        jdbc.update("DELETE FROM public.anuncio WHERE id_anuncio=?",id);
        return true;
    }
    record Pendiente(long id, String referencia) { }
    Pendiente tomarPendiente() {
        return jdbc.query("SELECT id,referencia_archivo FROM public.anuncio_archivo_pendiente_borrado ORDER BY coalesce(ultimo_intento,creado_en),id FOR UPDATE SKIP LOCKED LIMIT 1",
                (rs,n) -> new Pendiente(rs.getLong(1),rs.getString(2))).stream().findFirst().orElse(null);
    }
    void completado(long id) { jdbc.update("DELETE FROM public.anuncio_archivo_pendiente_borrado WHERE id=?",id); }
    void fallido(long id) { jdbc.update("UPDATE public.anuncio_archivo_pendiente_borrado SET intentos=intentos+1,ultimo_intento=CURRENT_TIMESTAMP,ultimo_error='Error al borrar en almacenamiento' WHERE id=?",id); }
}
